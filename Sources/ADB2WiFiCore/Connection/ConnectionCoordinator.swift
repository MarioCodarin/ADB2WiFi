import Foundation

@MainActor
public final class ConnectionCoordinator {
    public static let disconnectHelpText =
        "Disconnects this computer from the phone’s Wi-Fi ADB endpoint. It does not disable the phone’s TCP listener."

    private static let connectDeadline: Duration = .seconds(20)
    private static let retryDelay: Duration = .milliseconds(500)
    private static let defaultPort = 5555

    private let store: DeviceStore
    private let client: ADBClient
    private let clock: any Sleeping

    private var connectingIdentities: Set<DeviceIdentity> = []
    private var lastAddressByIdentity: [DeviceIdentity: String] = [:]

    public init(store: DeviceStore, client: ADBClient, clock: any Sleeping) {
        self.store = store
        self.client = client
        self.clock = clock
    }

    public convenience init(store: DeviceStore, client: ADBClient) {
        self.init(store: store, client: client, clock: DefaultSleeper())
    }

    public func connect(identity: DeviceIdentity, manualAddress: String? = nil) async {
        guard !connectingIdentities.contains(identity) else { return }
        connectingIdentities.insert(identity)
        defer { connectingIdentities.remove(identity) }

        do {
            try await runConnect(identity: identity, manualAddress: manualAddress)
        } catch is CancellationError {
            return
        } catch {
            fail(identity, mapError(error))
        }
    }

    public func disconnect(identity: DeviceIdentity) async {
        guard var device = store.device(for: identity) else { return }
        let endpoint = device.network?.serial ?? lastAddressByIdentity[identity]
        guard let endpoint else { return }
        do {
            try await client.disconnect(endpoint: endpoint)
        } catch is CancellationError {
            return
        } catch {
            fail(identity, mapError(error))
            return
        }
        device.network = nil
        device.operation = .idle
        store.update(device)
    }

    public func retry(identity: DeviceIdentity) async {
        await connect(identity: identity, manualAddress: lastAddressByIdentity[identity])
    }

    private func runConnect(identity: DeviceIdentity, manualAddress: String?) async throws {
        guard let snapshot = store.device(for: identity) else {
            throw AppError.usbRemoved
        }
        guard let usb = snapshot.usb else {
            throw AppError.usbRemoved
        }
        switch usb.state {
        case .unauthorized:
            throw AppError.authorizationPending
        case .offline, .unknown:
            throw AppError.deviceOffline
        case .device:
            break
        }

        let usbSerial = usb.serial
        let capturedSerialNo = identity.serialNo

        update(identity) { $0.operation = .connecting(.findingAddress) }
        let addresses = try await client.wifiAddresses(serial: usbSerial)

        let endpoint: String
        if let manual = manualAddress {
            guard let parsed = Self.normalizedEndpoint(manual) else {
                throw AppError.missingWiFiAddress
            }
            endpoint = parsed
        } else if let unambiguous = WiFiAddressParser.unambiguous(addresses) {
            endpoint = "\(unambiguous.ipv4):\(Self.defaultPort)"
        } else if addresses.isEmpty {
            throw AppError.missingWiFiAddress
        } else {
            let suggested = Self.suggestedIPv4(from: addresses)
            update(identity) { $0.operation = .awaitingAddress(suggested: suggested) }
            return
        }

        lastAddressByIdentity[identity] = endpoint

        try await ensureUSBPresent(serial: usbSerial)

        update(identity) { $0.operation = .connecting(.enablingWifi) }
        try await client.tcpip(serial: usbSerial, port: Self.defaultPort)

        update(identity) { $0.operation = .connecting(.connecting) }
        try await connectWithRetry(endpoint: endpoint)

        update(identity) { $0.operation = .connecting(.verifying) }
        let remoteSerial = try await client.serialNo(serial: endpoint)
        guard !remoteSerial.isEmpty, remoteSerial == capturedSerialNo else {
            throw AppError.identityMismatch
        }

        update(identity) { device in
            device.network = Transport(serial: endpoint, state: .device, verified: true)
            device.operation = .readyToUnplug
        }
    }

    /// USB unplug before `tcpip` is fatal; after `tcpip` the daemon restart is expected.
    private func ensureUSBPresent(serial: String) async throws {
        let transports = try await client.devices()
        guard let usb = transports.first(where: { $0.serial == serial && !$0.isNetwork }) else {
            throw AppError.usbRemoved
        }
        switch usb.state {
        case .unauthorized:
            throw AppError.authorizationPending
        case .offline, .unknown:
            throw AppError.deviceOffline
        case .device:
            break
        }
    }

    /// `adb connect` timeout is the remaining 20s budget, not a fresh 8s that can overrun it.
    private func connectWithRetry(endpoint: String) async throws {
        let deadline = clock.now + Self.connectDeadline
        while true {
            let now = clock.now
            if now >= deadline {
                throw AppError.unreachableEndpoint
            }
            let remaining = deadline - now
            do {
                try await client.connect(endpoint: endpoint, timeout: remaining)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch ADBError.timeout {
                throw ADBError.timeout
            } catch {
                let after = clock.now
                if after >= deadline {
                    throw AppError.unreachableEndpoint
                }
                let remainingAfter = deadline - after
                let delay = min(Self.retryDelay, remainingAfter)
                try await clock.sleep(for: delay)
            }
        }
    }

    private func update(_ identity: DeviceIdentity, _ body: (inout Device) -> Void) {
        guard var device = store.device(for: identity) else { return }
        body(&device)
        store.update(device)
    }

    private func fail(_ identity: DeviceIdentity, _ error: AppError) {
        update(identity) { $0.operation = .failed(error) }
    }

    private func mapError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        switch error {
        case ADBError.timeout:
            return .timeout
        case ADBError.unauthorized:
            return .authorizationPending
        case ADBError.missingExecutable:
            return .missingADB
        case ADBError.unparseable(let output):
            return .adbOutput(output)
        case ADBError.nonZeroExit(let result):
            let message = [result.stderr, result.stdout].first { !$0.isEmpty } ?? "exit \(result.exitCode)"
            return .adbOutput(message)
        default:
            return .adbOutput(String(describing: error))
        }
    }

    /// `#.#.#.#`, optional `:port`; append `:5555` when the port is omitted.
    private static func normalizedEndpoint(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = trimmed.wholeMatch(of: /^(\d+\.\d+\.\d+\.\d+)(?::(\d+))?$/) else {
            return nil
        }
        let ip = String(match.1)
        if let port = match.2 {
            return "\(ip):\(port)"
        }
        return "\(ip):5555"
    }

    /// Prefer the first `wlan*` / `wifi*` (not `swlan*`); otherwise the first Wi-Fi-like address.
    private static func suggestedIPv4(from addresses: [WiFiAddress]) -> String? {
        if let preferred = addresses.first(where: {
            $0.interface.hasPrefix("wlan") || $0.interface.hasPrefix("wifi")
        }) {
            return preferred.ipv4
        }
        return addresses.first?.ipv4
    }
}
