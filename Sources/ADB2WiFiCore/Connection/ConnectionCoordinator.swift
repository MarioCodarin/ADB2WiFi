import Foundation

@MainActor
public final class ConnectionCoordinator {
    public static let disconnectHelpText =
        "Disconnects this computer from the phone’s Wi-Fi ADB endpoint. It does not disable the phone’s TCP listener."

    private static let connectDeadline: Duration = .seconds(20)
    private static let retryDelay: Duration = .milliseconds(500)

    private let store: DeviceStore
    private let clock: any Sleeping
    private let clientProvider: @MainActor () -> ADBClient?

    private var connectingIdentities: Set<DeviceIdentity> = []
    private var isReconnectingRemembered = false

    private var port: Int { store.port }

    public init(
        store: DeviceStore,
        clock: any Sleeping,
        clientProvider: @escaping @MainActor () -> ADBClient?
    ) {
        self.store = store
        self.clock = clock
        self.clientProvider = clientProvider
    }

    public convenience init(store: DeviceStore, client: ADBClient, clock: any Sleeping) {
        self.init(store: store, clock: clock, clientProvider: { client })
    }

    public convenience init(store: DeviceStore, client: ADBClient) {
        self.init(store: store, client: client, clock: DefaultSleeper())
    }

    public convenience init(
        store: DeviceStore,
        clientProvider: @escaping @MainActor () -> ADBClient?
    ) {
        self.init(store: store, clock: DefaultSleeper(), clientProvider: clientProvider)
    }

    public func connect(identity: DeviceIdentity, manualAddress: String? = nil) async {
        guard !connectingIdentities.contains(identity) else {
            Log.connection.debug("connect ignored: already in flight")
            return
        }
        guard let client = requireClient(for: identity) else { return }
        connectingIdentities.insert(identity)
        defer { connectingIdentities.remove(identity) }

        let started = ContinuousClock.now
        Log.connection.notice(
            "connect start device=\(identity.serialNo, privacy: .private) manual=\(manualAddress != nil, privacy: .public) port=\(self.port, privacy: .public)"
        )

        do {
            try await runConnect(identity: identity, manualAddress: manualAddress, client: client)
            let outcome = store.device(for: identity)?.operation.isAwaitingAddress == true ? "prompt" : "ok"
            Log.connection.notice(
                "connect \(outcome, privacy: .public) device=\(identity.serialNo, privacy: .private) duration=\((ContinuousClock.now - started).inMilliseconds, privacy: .public)ms"
            )
        } catch is CancellationError {
            Log.connection.notice("connect cancelled device=\(identity.serialNo, privacy: .private)")
            return
        } catch {
            let appError = AppError(mapping: error)
            Log.connection.error(
                "connect failed device=\(identity.serialNo, privacy: .private) error=\(String(describing: appError), privacy: .private) duration=\((ContinuousClock.now - started).inMilliseconds, privacy: .public)ms"
            )
            fail(identity, appError)
        }
    }

    public func disconnect(identity: DeviceIdentity) async {
        guard var device = store.device(for: identity) else { return }
        let endpoint = device.network?.serial ?? store.rememberedEndpoint(for: identity)
        guard let endpoint else {
            Log.connection.debug("disconnect ignored: no endpoint")
            return
        }
        guard let client = requireClient(for: identity) else { return }
        Log.connection.notice("disconnect device=\(identity.serialNo, privacy: .private)")
        do {
            try await client.disconnect(endpoint: endpoint)
        } catch is CancellationError {
            return
        } catch {
            let appError = AppError(mapping: error)
            Log.connection.error("disconnect failed error=\(String(describing: appError), privacy: .private)")
            fail(identity, appError)
            return
        }
        device.network = nil
        device.operation = .idle
        store.update(device)
        store.forgetEndpoint(for: identity)
        Log.connection.notice("disconnect ok")
    }

    /// Re-discovers the Wi-Fi IPv4 over USB.
    public func retry(identity: DeviceIdentity) async {
        await connect(identity: identity)
    }

    /// Quietly tries endpoints remembered from previous verified sessions. Runs once on
    /// launch and on wake; failures are logged but never surfaced as a global error.
    public func reconnectRememberedEndpoints() async {
        guard !isReconnectingRemembered else { return }
        guard store.autoReconnect else {
            Log.connection.debug("auto-reconnect disabled")
            return
        }
        guard connectingIdentities.isEmpty else { return }
        guard let client = clientProvider() else { return }
        let candidates = store.rememberedConnections
        guard !candidates.isEmpty else { return }

        isReconnectingRemembered = true
        defer { isReconnectingRemembered = false }

        Log.connection.notice("auto-reconnect start candidates=\(candidates.count, privacy: .public)")
        let deadline = ContinuousClock.now + .seconds(6)

        for remembered in candidates {
            if ContinuousClock.now >= deadline { break }
            if connectingIdentities.contains(remembered.identity) { continue }
            if let device = store.device(for: remembered.identity) {
                if device.isWiFiConnected || device.usb != nil { continue }
            }

            do {
                let connected = try await attemptRememberedConnection(
                    identity: remembered.identity,
                    endpoint: remembered.endpoint,
                    model: remembered.model,
                    timeout: .seconds(3),
                    client: client
                )
                if connected {
                    Log.connection.notice("auto-reconnect ok")
                } else {
                    Log.connection.notice("auto-reconnect skipped wrong device")
                }
            } catch is CancellationError {
                return
            } catch {
                Log.connection.info(
                    "auto-reconnect skipped error=\(String(describing: error), privacy: .private)"
                )
            }
        }
        Log.connection.debug("auto-reconnect finished")
    }

    /// Manual retry for a row in the recent list. Returns false so the row can show a hint.
    public func reconnectRemembered(identity: DeviceIdentity, model: String = "") async -> Bool {
        guard let endpoint = store.rememberedEndpoint(for: identity) else { return false }
        guard !connectingIdentities.contains(identity) else { return false }
        guard let client = clientProvider() else { return false }

        let rememberedModel = model.isEmpty
            ? (store.rememberedConnection(for: identity)?.model ?? "")
            : model
        Log.connection.notice("reconnect remembered device=\(identity.serialNo, privacy: .private)")

        do {
            let connected = try await attemptRememberedConnection(
                identity: identity,
                endpoint: endpoint,
                model: rememberedModel,
                timeout: .seconds(5),
                client: client
            )
            Log.connection.notice("reconnect remembered result=\(connected, privacy: .public)")
            return connected
        } catch is CancellationError {
            return false
        } catch {
            Log.connection.info(
                "reconnect remembered failed error=\(String(describing: error), privacy: .private)"
            )
            return false
        }
    }

    private func attemptRememberedConnection(
        identity: DeviceIdentity,
        endpoint: String,
        model: String,
        timeout: Duration,
        client: ADBClient
    ) async throws -> Bool {
        try await client.connect(endpoint: endpoint, timeout: timeout)
        let remoteSerial = try await client.serialNo(serial: endpoint)
        guard remoteSerial == identity.serialNo else { return false }

        store.rememberEndpoint(endpoint, model: model, for: identity)
        await store.refresh()
        // A poll may already have been in flight when the endpoint came up.
        if store.device(for: identity)?.network?.serial != endpoint {
            await store.refresh()
        }
        return store.device(for: identity)?.isWiFiConnected == true
    }

    /// Clears a prompt or failure. A running connection is not interruptible from the UI.
    public func cancel(identity: DeviceIdentity) {
        guard !connectingIdentities.contains(identity) else { return }
        update(identity) { $0.operation = .idle }
        Log.connection.notice("connect prompt cleared")
    }

    private func runConnect(identity: DeviceIdentity, manualAddress: String?, client: ADBClient) async throws {
        let port = self.port
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
            guard let parsed = Endpoint.normalize(manual, defaultPort: port) else {
                throw AppError.missingWiFiAddress
            }
            endpoint = parsed
        } else if let unambiguous = WiFiAddressParser.unambiguous(addresses) {
            endpoint = "\(unambiguous.ipv4):\(port)"
        } else if addresses.isEmpty {
            throw AppError.missingWiFiAddress
        } else {
            let suggested = Endpoint.suggestedIPv4(from: addresses)
            update(identity) { $0.operation = .awaitingAddress(suggested: suggested) }
            return
        }

        Log.connection.debug("endpoint selected endpoint=\(endpoint, privacy: .private)")

        try await ensureUSBPresent(serial: usbSerial, client: client)

        update(identity) { $0.operation = .connecting(.enablingWifi) }
        try await client.tcpip(serial: usbSerial, port: port)

        update(identity) { $0.operation = .connecting(.connecting) }
        try await connectWithRetry(endpoint: endpoint, client: client)

        update(identity) { $0.operation = .connecting(.verifying) }
        let remoteSerial = try await client.serialNo(serial: endpoint)
        guard !remoteSerial.isEmpty, remoteSerial == capturedSerialNo else {
            Log.connection.error("identity mismatch")
            try await disconnectMismatchedEndpoint(endpoint, client: client)
            throw AppError.identityMismatch
        }

        update(identity) { device in
            device.network = Transport(serial: endpoint, state: .device, verified: true)
            device.operation = .readyToUnplug
        }
        store.rememberEndpoint(endpoint, model: snapshot.model, for: identity)
    }

    /// Drop the foreign `adb connect` so Retry cannot hit `already connected to`.
    private func disconnectMismatchedEndpoint(_ endpoint: String, client: ADBClient) async throws {
        do {
            try await client.disconnect(endpoint: endpoint)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Still fail as identityMismatch; the connect must not remain sticky.
            Log.connection.error("endpoint cleanup failed error=\(String(describing: error), privacy: .private)")
        }
    }

    /// USB unplug before `tcpip` is fatal; after `tcpip` the daemon restart is expected.
    private func ensureUSBPresent(serial: String, client: ADBClient) async throws {
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
    private func connectWithRetry(endpoint: String, client: ADBClient) async throws {
        let deadline = clock.now + Self.connectDeadline
        var attempt = 0
        while true {
            let now = clock.now
            if now >= deadline {
                throw AppError.unreachableEndpoint
            }
            attempt += 1
            let remaining = deadline - now
            Log.connection.debug("connect attempt=\(attempt, privacy: .public)")
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

    private func requireClient(for identity: DeviceIdentity) -> ADBClient? {
        guard let client = clientProvider() else {
            Log.connection.error("connect failed: adb missing")
            fail(identity, .missingADB)
            return nil
        }
        return client
    }

    private func update(_ identity: DeviceIdentity, _ body: (inout Device) -> Void) {
        guard var device = store.device(for: identity) else { return }
        let before = device.operation
        body(&device)
        if before != device.operation {
            Log.connection.debug("state=\(Self.label(for: device.operation), privacy: .public)")
        }
        store.update(device)
    }

    private static func label(for operation: OperationState) -> String {
        switch operation {
        case .idle: "idle"
        case .connecting(let step): "connecting.\(step.rawValue)"
        case .awaitingAddress: "awaitingAddress"
        case .readyToUnplug: "readyToUnplug"
        case .failed(let error): "failed.\(error.title)"
        }
    }

    private func fail(_ identity: DeviceIdentity, _ error: AppError) {
        update(identity) { $0.operation = .failed(error) }
    }
}
