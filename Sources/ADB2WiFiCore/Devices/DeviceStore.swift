import Foundation
import Observation

public protocol Sleeping: Sendable {
    func sleep(for duration: Duration) async throws
    var now: ContinuousClock.Instant { get }
}

extension Sleeping {
    public var now: ContinuousClock.Instant { ContinuousClock().now }
}

struct DefaultSleeper: Sleeping {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

@MainActor
@Observable
public final class DeviceStore {
    public private(set) var devices: [Device] = []
    public private(set) var adbVersion: String?
    public private(set) var globalError: AppError?
    public var isPopoverOpen = false {
        didSet {
            if oldValue != isPopoverOpen {
                intervalWaitTask?.cancel()
            }
        }
    }

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let runner: any CommandRunning
    @ObservationIgnored private let clock: any Sleeping
    @ObservationIgnored private let fileManager: any FileChecking
    @ObservationIgnored private let pathEnv: String
    @ObservationIgnored private let environment: [String: String]
    @ObservationIgnored private let homeDirectory: URL

    @ObservationIgnored private var identityByTransportSerial: [String: DeviceIdentity] = [:]
    @ObservationIgnored private var modelBySerialNo: [String: String] = [:]
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var intervalWaitTask: Task<Void, Error>?

    public convenience init(settings: AppSettings, runner: any CommandRunning) {
        self.init(
            settings: settings,
            runner: runner,
            clock: DefaultSleeper(),
            fileManager: FileManager.default,
            pathEnv: ProcessInfo.processInfo.environment["PATH"] ?? "",
            environment: ProcessInfo.processInfo.environment,
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        )
    }

    public convenience init(settings: AppSettings, runner: any CommandRunning, clock: any Sleeping) {
        self.init(
            settings: settings,
            runner: runner,
            clock: clock,
            fileManager: FileManager.default,
            pathEnv: ProcessInfo.processInfo.environment["PATH"] ?? "",
            environment: ProcessInfo.processInfo.environment,
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        )
    }

    init(
        settings: AppSettings,
        runner: any CommandRunning,
        clock: any Sleeping,
        fileManager: any FileChecking,
        pathEnv: String,
        environment: [String: String],
        homeDirectory: URL
    ) {
        self.settings = settings
        self.runner = runner
        self.clock = clock
        self.fileManager = fileManager
        self.pathEnv = pathEnv
        self.environment = environment
        self.homeDirectory = homeDirectory
    }

    public func makeClient() -> ADBClient? {
        guard let executable = resolvedExecutable() else { return nil }
        return ADBClient(executable: executable, runner: runner)
    }

    public func refreshVersion() async {
        guard let client = makeClient() else {
            adbVersion = nil
            return
        }
        do {
            adbVersion = try await client.version()
        } catch is CancellationError {
            return
        } catch {
            adbVersion = nil
        }
    }

    public func refresh() async {
        guard let client = makeClient() else {
            globalError = .missingADB
            return
        }
        do {
            let transports = try await client.devices()
            let physical = transports.filter { !$0.isEmulator }
            let presentSerials = Set(physical.map(\.serial))
            identityByTransportSerial = identityByTransportSerial.filter { presentSerials.contains($0.key) }
            try Task.checkCancellation()

            for transport in physical where transport.state == .device {
                if identityByTransportSerial[transport.serial] == nil {
                    if let serialNo = try await ignoreGetpropFailure({
                        try await client.serialNo(serial: transport.serial)
                    }), !serialNo.isEmpty {
                        identityByTransportSerial[transport.serial] = DeviceIdentity(serialNo: serialNo)
                    }
                }
                let identity = identityByTransportSerial[transport.serial]
                    ?? DeviceIdentity(serialNo: transport.serial)
                if modelBySerialNo[identity.serialNo] == nil {
                    if let model = try await ignoreGetpropFailure({
                        try await client.model(serial: transport.serial)
                    }), !model.isEmpty {
                        modelBySerialNo[identity.serialNo] = model
                    }
                }
            }

            var identities = identityByTransportSerial
            for transport in physical where identities[transport.serial] == nil {
                identities[transport.serial] = DeviceIdentity(serialNo: transport.serial)
            }

            devices = TransportMerger.merge(
                existing: devices,
                transports: physical,
                identities: identities,
                models: modelBySerialNo
            )
            globalError = nil
        } catch is CancellationError {
            return
        } catch {
            globalError = mapError(error)
        }
    }

    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.refresh()
                await self.waitForNextInterval()
            }
        }
    }

    public func stop() {
        intervalWaitTask?.cancel()
        pollTask?.cancel()
        pollTask = nil
    }

    public func update(_ device: Device) {
        if let index = devices.firstIndex(where: { $0.identity == device.identity }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }

    public func device(for identity: DeviceIdentity) -> Device? {
        devices.first { $0.identity == identity }
    }

    private func resolvedExecutable() -> URL? {
        ADBExecutable.resolve(
            override: settings.adbPathOverride,
            fileManager: fileManager,
            pathEnv: pathEnv,
            environment: environment,
            homeDirectory: homeDirectory
        )
    }

    private func waitForNextInterval() async {
        let interval: Duration = isPopoverOpen ? .seconds(2) : .seconds(10)
        let wait = Task { [clock] in
            try await clock.sleep(for: interval)
        }
        intervalWaitTask = wait
        await withTaskCancellationHandler {
            _ = try? await wait.value
        } onCancel: {
            wait.cancel()
        }
        intervalWaitTask = nil
    }

    private func ignoreGetpropFailure(_ body: () async throws -> String) async throws -> String? {
        do {
            return try await body()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    private func mapError(_ error: Error) -> AppError {
        switch error {
        case ADBError.missingExecutable:
            return .missingADB
        case ADBError.timeout:
            return .timeout
        case ADBError.unauthorized:
            return .authorizationPending
        case ADBError.unparseable(let output):
            return .adbOutput(output)
        case ADBError.nonZeroExit(let result):
            let message = [result.stderr, result.stdout].first { !$0.isEmpty } ?? "exit \(result.exitCode)"
            return .adbOutput(message)
        default:
            return .adbOutput(String(describing: error))
        }
    }
}
