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

/// Adaptive cadence: fast while a connection is in flight, relaxed when the popover is
/// open, and slow in the background. The app spawns no `adb` process while the Mac sleeps.
public enum ADBPolling {
    public static let connecting: Duration = .seconds(1)
    public static let popoverOpen: Duration = .seconds(3)
    public static let background: Duration = .seconds(60)
}

@MainActor
@Observable
public final class DeviceStore {
    public private(set) var devices: [Device] = []
    public private(set) var adbVersion: String?
    public private(set) var adbPath: URL?
    public private(set) var hasLoaded = false
    public private(set) var globalError: AppError?
    public private(set) var isRefreshing = false
    public var isPopoverOpen = false {
        didSet {
            guard oldValue != isPopoverOpen else { return }
            Log.devices.info("popover open=\(self.isPopoverOpen, privacy: .public)")
            // Wake the loop so opening the popover refreshes immediately instead of
            // waiting out a background interval.
            if isPopoverOpen { intervalWaitTask?.cancel() }
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
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var userRefreshCount = 0

    public var port: Int { settings.port }
    public var connectedCount: Int { devices.filter(\.isWiFiConnected).count }
    public var autoReconnect: Bool { settings.autoReconnect }

    /// Remembered endpoint candidates, oldest order is not significant; sort for determinism.
    public var rememberedConnections: [(identity: DeviceIdentity, endpoint: String)] {
        settings.rememberedEndpoints
            .sorted { $0.key < $1.key }
            .map { (DeviceIdentity(serialNo: $0.key), $0.value) }
    }

    public func rememberedEndpoint(for identity: DeviceIdentity) -> String? {
        settings.rememberedEndpoint(for: identity.serialNo)
    }

    public func rememberEndpoint(_ endpoint: String, for identity: DeviceIdentity) {
        settings.remember(endpoint: endpoint, for: identity.serialNo)
    }

    public func forgetEndpoint(for identity: DeviceIdentity) {
        settings.forgetEndpoint(for: identity.serialNo)
    }

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
        adbPath = resolvedExecutable()
        guard let executable = adbPath else {
            adbVersion = nil
            Log.settings.notice("adb version unavailable")
            return
        }
        let client = ADBClient(executable: executable, runner: runner)
        do {
            let version = try await client.version()
            adbVersion = version
            Log.settings.notice("adb version=\(version, privacy: .public)")
        } catch is CancellationError {
            return
        } catch {
            adbVersion = nil
            Log.settings.error("adb version failed error=\(String(describing: error), privacy: .private)")
        }
    }

    /// Coalesced: concurrent callers share one `adb devices -l` invocation. This keeps
    /// overlapping timer/user refreshes from spawning duplicate processes.
    public func refresh(userInitiated: Bool = false) async {
        if userInitiated {
            userRefreshCount += 1
            isRefreshing = true
        }
        defer {
            if userInitiated {
                userRefreshCount -= 1
                if userRefreshCount == 0 { isRefreshing = false }
            }
        }

        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { await self.performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        let started = ContinuousClock.now
        defer { hasLoaded = true }
        adbPath = resolvedExecutable()
        guard let executable = adbPath else {
            if globalError != .missingADB {
                Log.devices.error("adb missing; keeping \(self.devices.count, privacy: .public) cached device(s)")
            }
            globalError = .missingADB
            return
        }
        let client = ADBClient(executable: executable, runner: runner)

        do {
            let transports = try await client.devices()
            try Task.checkCancellation()

            let physical = transports.filter { !$0.isEmulator }
            let presentSerials = Set(physical.map(\.serial))
            identityByTransportSerial = identityByTransportSerial.filter { presentSerials.contains($0.key) }

            for transport in physical where transport.state == .device {
                if identityByTransportSerial[transport.serial] == nil {
                    if let serialNo = try await ignoreGetpropFailure({
                        try await client.serialNo(serial: transport.serial)
                    }), !serialNo.isEmpty {
                        identityByTransportSerial[transport.serial] = DeviceIdentity(serialNo: serialNo)
                        Log.devices.debug(
                            "identity resolved transport=\(transport.serial, privacy: .private) serial=\(serialNo, privacy: .private)"
                        )
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

            let previous = Set(devices.map(\.identity))
            devices = TransportMerger.merge(
                existing: devices,
                transports: physical,
                identities: identities,
                models: modelBySerialNo
            )
            globalError = nil

            let current = Set(devices.map(\.identity))
            let added = current.subtracting(previous).count
            let removed = previous.subtracting(current).count
            let elapsed = (ContinuousClock.now - started).inMilliseconds
            if added > 0 || removed > 0 {
                Log.devices.notice(
                    "poll total=\(self.devices.count, privacy: .public) added=\(added, privacy: .public) removed=\(removed, privacy: .public) duration=\(elapsed, privacy: .public)ms"
                )
            } else {
                Log.devices.info(
                    "poll total=\(self.devices.count, privacy: .public) duration=\(elapsed, privacy: .public)ms"
                )
            }
        } catch is CancellationError {
            return
        } catch {
            globalError = AppError(mapping: error)
            Log.devices.error(
                "poll failed error=\(String(describing: error), privacy: .private) duration=\((ContinuousClock.now - started).inMilliseconds, privacy: .public)ms"
            )
        }
    }

    public func start() {
        guard pollTask == nil else { return }
        Log.devices.notice("polling started")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                guard !Task.isCancelled else { return }
                await self.waitForNextInterval()
            }
        }
    }

    public func stop() {
        intervalWaitTask?.cancel()
        pollTask?.cancel()
        refreshTask?.cancel()
        pollTask = nil
        Log.devices.notice("polling stopped")
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

    #if DEBUG
    /// Debug-only UI seeding. Release builds never contain fixture devices.
    public func replaceDevicesForPreview(_ devices: [Device]) {
        self.devices = devices
        hasLoaded = true
    }
    #endif

    public func resolvedExecutable() -> URL? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ADB2WIFI_FORCE_MISSING_ADB"] == "1" {
            return nil
        }
        #endif
        let url = ADBExecutable.resolve(
            override: settings.adbPathOverride,
            fileManager: fileManager,
            pathEnv: pathEnv,
            environment: environment,
            homeDirectory: homeDirectory
        )
        Log.settings.debug("resolved adb path=\(url?.path ?? "none", privacy: .private)")
        return url
    }

    private var currentPollInterval: Duration {
        if devices.contains(where: { $0.operation.isInFlight }) { return ADBPolling.connecting }
        return isPopoverOpen ? ADBPolling.popoverOpen : ADBPolling.background
    }

    private func waitForNextInterval() async {
        let interval = currentPollInterval
        Log.devices.debug("poll sleep interval=\(interval.inMilliseconds, privacy: .public)ms")
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
}
