import Foundation
import Testing
@testable import ADB2WiFiCore

private let fakeADB = URL(fileURLWithPath: "/tmp/adb2wifi-test-adb")
private let pixel = Device.testUSBAuthorized
private let samsung = Device(
    identity: DeviceIdentity(serialNo: "TEST00000002"),
    model: "Pixel 8",
    usb: Transport(serial: "TEST00000002", state: .device)
)
private let samsungIdentity = samsung.identity

private let pixelUSBListing = """
List of devices attached
TEST00000001         device usb:1-1 product:shiba model:Pixel_8 device:shiba transport_id:2
"""

private let twoPhoneListing = """
List of devices attached
TEST00000001         device usb:1-1 product:shiba model:Pixel_8 device:shiba transport_id:2
TEST00000002            device usb:2-1 product:husky model:Pixel_8
"""

private let wlan0Only = """
1: lo    inet 127.0.0.1/8 ...
12: wlan0    inet 192.0.2.42/24 ...
14: rmnet_data0 inet 10.132.4.8/30 ...
"""

private let samsungAP = """
12: wlan0 inet 192.0.2.42/24
13: swlan0 inet 198.51.100.43/24
"""

private let loopbackAndRmnet = """
1: lo    inet 127.0.0.1/8 ...
14: rmnet_data0 inet 10.132.4.8/30 ...
"""

private let unauthorizedUSBListing = """
List of devices attached
ABCDEF12               unauthorized usb:1-1 transport_id:4
"""

private let emptyDeviceListing = """
List of devices attached
"""

private let unauthorizedIdentity = DeviceIdentity(serialNo: "ABCDEF12")

private func ok(_ stdout: String, stderr: String = "", exitCode: Int32 = 0) -> CommandResult {
    CommandResult(exitCode: exitCode, stdout: stdout, stderr: stderr)
}

private struct ExistsSet: FileChecking {
    var paths: Set<String>
    init(_ paths: [String]) { self.paths = Set(paths) }
    func fileExists(atPath path: String) -> Bool { paths.contains(path) }
    func isExecutableFile(atPath path: String) -> Bool { paths.contains(path) }
}

@MainActor
private func makeHarness(
    runner: FakeCommandRunner,
    clock: any Sleeping = ImmediateClock(),
    port: Int = 5555
) -> (DeviceStore, ConnectionCoordinator) {
    let settings = AppSettings(storage: InMemoryDefaults())
    settings.adbPathOverride = fakeADB
    settings.port = port
    let store = DeviceStore(
        settings: settings,
        runner: runner,
        clock: clock,
        fileManager: ExistsSet([fakeADB.path]),
        pathEnv: "",
        environment: [:],
        homeDirectory: URL(fileURLWithPath: "/tmp")
    )
    let client = ADBClient(executable: fakeADB, runner: runner)
    let coordinator = ConnectionCoordinator(store: store, client: client, clock: clock)
    return (store, coordinator)
}

private func failFast(_ arguments: [String]) async throws -> CommandResult {
    throw ADBError.timeout
}

/// Virtual clock: `sleep` advances `now` without waiting on the wall clock.
private final class AdvancingClock: Sleeping, @unchecked Sendable {
    private let lock = NSLock()
    private var instant = ContinuousClock().now

    var now: ContinuousClock.Instant {
        lock.withLock { instant }
    }

    func sleep(for duration: Duration) async throws {
        lock.withLock { instant += duration }
    }
}

/// Parks the first in-flight command until `release()`, and lets the test wait until it arrives.
private final class CommandGate: @unchecked Sendable {
    private let lock = NSLock()
    private var arrivedWaiters: [CheckedContinuation<Void, Never>] = []
    private var arrived = false
    private var proceedWaiters: [CheckedContinuation<Void, Never>] = []
    private var proceed = false

    func waitToProceed() async {
        let pendingArrived: [CheckedContinuation<Void, Never>] = lock.withLock {
            arrived = true
            let pending = arrivedWaiters
            arrivedWaiters.removeAll()
            return pending
        }
        pendingArrived.forEach { $0.resume() }

        await withCheckedContinuation { continuation in
            let alreadyReleased = lock.withLock { () -> Bool in
                if proceed { return true }
                proceedWaiters.append(continuation)
                return false
            }
            if alreadyReleased {
                continuation.resume()
            }
        }
    }

    func waitUntilArrived() async {
        await withCheckedContinuation { continuation in
            let alreadyArrived = lock.withLock { () -> Bool in
                if arrived { return true }
                arrivedWaiters.append(continuation)
                return false
            }
            if alreadyArrived {
                continuation.resume()
            }
        }
    }

    func release() {
        let pending: [CheckedContinuation<Void, Never>] = lock.withLock {
            proceed = true
            let waiters = proceedWaiters
            proceedWaiters.removeAll()
            return waiters
        }
        pending.forEach { $0.resume() }
    }
}

@Test @MainActor
func oneClickConnectsAndVerifiesIdentity() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in ok("failed to connect to 192.0.2.42:5555") },
        { _ in ok("connected to 192.0.2.42:5555\n") },
        { _ in ok("TEST00000001\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    let device = store.device(for: pixel.identity)!
    #expect(device.isWiFiConnected)
    #expect(device.operation == .readyToUnplug)
    #expect(runner.tcpipSerials == ["TEST00000001"])
    #expect(runner.connectEndpoints == ["192.0.2.42:5555", "192.0.2.42:5555"])
}

@Test @MainActor
func promptsForAddressBeforeTcpipWhenAmbiguous() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(samsungAP) },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    let operation = store.device(for: pixel.identity)?.operation
    #expect(operation?.isAwaitingAddress == true)
    if case .awaitingAddress(let suggested) = operation {
        #expect(suggested == "192.0.2.42")
    } else {
        Issue.record("expected awaitingAddress, got \(String(describing: operation))")
    }
    #expect(runner.invokedCommands.contains { $0.contains("tcpip") } == false)
}

@Test @MainActor
func failedIdentityVerificationDoesNotMarkWifiConnected() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in ok("connected to 192.0.2.42:5555\n") },
        { _ in ok("OTHER_SERIAL\n") },
        { _ in ok("disconnected 192.0.2.42:5555\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(runner.disconnectEndpoints == ["192.0.2.42:5555"])
    #expect(store.device(for: pixel.identity)?.isWiFiConnected == false)
    #expect(store.device(for: pixel.identity)?.network?.verified != true)
    #expect(store.device(for: pixel.identity)?.operation == .failed(.identityMismatch))
}

@Test @MainActor
func connectOnePhoneDoesNotTargetTheOther() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(twoPhoneListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok("TEST00000002\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in ok("connected to 192.0.2.42:5555\n") },
        { _ in ok("TEST00000001\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()
    runner.clearCalls()

    await coordinator.connect(identity: pixel.identity)
    #expect(runner.targetedSerials.allSatisfy { $0 == "TEST00000001" || $0.hasPrefix("192.0.2.") })
    #expect(!runner.targetedSerials.contains("TEST00000002"))
    #expect(store.device(for: samsungIdentity)?.operation == .idle)
}

@Test @MainActor
func retriesConnectWithinTwentySecondDeadline() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in ok("failed to connect to 192.0.2.42:5555") },
        { _ in ok("failed to connect to 192.0.2.42:5555") },
        { _ in ok("connected to 192.0.2.42:5555\n") },
        { _ in ok("TEST00000001\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(runner.connectEndpoints == [
        "192.0.2.42:5555",
        "192.0.2.42:5555",
        "192.0.2.42:5555",
    ])
    #expect(store.device(for: pixel.identity)?.isWiFiConnected == true)
    #expect(store.device(for: pixel.identity)?.operation == .readyToUnplug)
    let connectTimeouts = runner.calls.filter { $0.arguments.first == "connect" }.map(\.timeout)
    #expect(connectTimeouts.count == 3)
    #expect(connectTimeouts.allSatisfy { $0 <= .seconds(20) && $0 > .seconds(0) })
}

@Test @MainActor
func missingWifiAddressShowsGuidanceAndRetry() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(loopbackAndRmnet) },
        { _ in ok(loopbackAndRmnet) },
        failFast,
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(store.device(for: pixel.identity)?.operation == .failed(.missingWiFiAddress))
    #expect(runner.tcpipCount == 0)

    await coordinator.retry(identity: pixel.identity)
    #expect(store.device(for: pixel.identity)?.operation == .failed(.missingWiFiAddress))
    #expect(runner.tcpipCount == 0)
}

@Test @MainActor
func unauthorizedUSBDoesNotCallTcpip() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(unauthorizedUSBListing) },
        failFast,
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: unauthorizedIdentity)
    #expect(store.device(for: unauthorizedIdentity)?.operation == .failed(.authorizationPending))
    #expect(runner.tcpipCount == 0)
    #expect(runner.invokedCommands.contains { $0.contains("tcpip") } == false)
}

@Test @MainActor
func usbUnplugBeforeTcpipFailsWithUsbRemoved() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(emptyDeviceListing) },
        failFast,
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(store.device(for: pixel.identity)?.operation == .failed(.usbRemoved))
    #expect(runner.tcpipCount == 0)
}

@Test @MainActor
func duplicateClickIgnoredWhileConnecting() async {
    let gate = CommandGate()
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in
            await gate.waitToProceed()
            return ok(wlan0Only)
        },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in ok("connected to 192.0.2.42:5555\n") },
        { _ in ok("TEST00000001\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    let first = Task { await coordinator.connect(identity: pixel.identity) }
    await gate.waitUntilArrived()
    await coordinator.connect(identity: pixel.identity)
    #expect(runner.tcpipCount == 0)
    gate.release()
    await first.value
    #expect(runner.tcpipCount == 1)
    #expect(store.device(for: pixel.identity)?.isWiFiConnected == true)
}

@Test @MainActor
func otherDeviceRemainsIdleWhileOneConnects() async {
    let gate = CommandGate()
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(twoPhoneListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok("TEST00000002\n") },
        { _ in ok("Pixel 8\n") },
        { _ in
            await gate.waitToProceed()
            return ok(wlan0Only)
        },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in ok("connected to 192.0.2.42:5555\n") },
        { _ in ok("TEST00000001\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()
    runner.clearCalls()
    #expect(store.device(for: samsung.identity)?.operation == .idle)

    let connecting = Task { await coordinator.connect(identity: pixel.identity) }
    await gate.waitUntilArrived()
    #expect(store.device(for: pixel.identity)?.operation == .connecting(.findingAddress))
    #expect(store.device(for: samsung.identity)?.operation == .idle)
    gate.release()
    await connecting.value

    #expect(store.device(for: pixel.identity)?.operation == .readyToUnplug)
    #expect(store.device(for: samsung.identity)?.operation == .idle)
    #expect(!runner.targetedSerials.contains("TEST00000002"))
}

@Test @MainActor
func disconnectRemovesOnlyThatEndpoint() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(twoPhoneListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok("TEST00000002\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok("disconnected 192.0.2.42:5555\n") },
        failFast,
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    var pixelDevice = store.device(for: pixel.identity)!
    pixelDevice.network = Transport(serial: "192.0.2.42:5555", state: .device, verified: true)
    store.update(pixelDevice)
    var samsungDevice = store.device(for: samsung.identity)!
    samsungDevice.network = Transport(serial: "192.0.2.43:5555", state: .device, verified: true)
    store.update(samsungDevice)
    runner.clearCalls()

    await coordinator.disconnect(identity: pixel.identity)
    #expect(runner.disconnectEndpoints == ["192.0.2.42:5555"])
    #expect(!runner.invokedCommands.contains { $0.contains("kill-server") })
    #expect(store.device(for: pixel.identity)?.isWiFiConnected == false)
    #expect(store.device(for: samsung.identity)?.isWiFiConnected == true)
    #expect(
        ConnectionCoordinator.disconnectHelpText
            == "Disconnects this computer from the phone’s Wi-Fi ADB endpoint. It does not disable the phone’s TCP listener."
    )
}

@Test @MainActor
func timeoutDuringConnectMapsToTimeoutError() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in throw ADBError.timeout },
        failFast,
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(store.device(for: pixel.identity)?.operation == .failed(.timeout))
    #expect(store.device(for: pixel.identity)?.isWiFiConnected == false)
}

@Test @MainActor
func unreachableEndpointMapsToGuidance() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 5555\n") },
    ])
    runner.fallback = { arguments in
        if arguments.first == "connect" {
            return ok("failed to connect to 192.0.2.42:5555")
        }
        throw ADBError.timeout
    }
    let (store, coordinator) = makeHarness(runner: runner, clock: AdvancingClock())
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(store.device(for: pixel.identity)?.operation == .failed(.unreachableEndpoint))
    #expect(store.device(for: pixel.identity)?.isWiFiConnected == false)
    #expect(!runner.connectEndpoints.isEmpty)
    #expect(runner.connectEndpoints.allSatisfy { $0 == "192.0.2.42:5555" })
}

private let wlan0NewLease = """
1: lo    inet 127.0.0.1/8 ...
12: wlan0    inet 192.0.2.99/24 ...
14: rmnet_data0 inet 10.132.4.8/30 ...
"""

private final class AddressLookupCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}

@Test @MainActor
func retryRereadsWifiAddressInsteadOfReusingLastIP() async {
    let lookups = AddressLookupCounter()
    let runner = FakeCommandRunner()
    runner.fallback = { arguments in
        if arguments == ["devices", "-l"] {
            return ok(pixelUSBListing)
        }
        if arguments.contains(where: { $0.contains("ip -o -4 addr show up") }) {
            return ok(lookups.next() == 1 ? wlan0Only : wlan0NewLease)
        }
        if arguments.count >= 3, arguments[2] == "tcpip" {
            return ok("restarting in TCP mode port: 5555\n")
        }
        if arguments.first == "connect" {
            let endpoint = arguments[1]
            if endpoint == "192.0.2.42:5555" {
                throw ADBError.timeout
            }
            return ok("connected to \(endpoint)\n")
        }
        if arguments.contains(where: { $0.contains("getprop ro.serialno") }) {
            return ok("TEST00000001\n")
        }
        if arguments.contains(where: { $0.contains("getprop ro.product.model") }) {
            return ok("Pixel 8\n")
        }
        return ok("")
    }
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(store.device(for: pixel.identity)?.operation == .failed(.timeout))
    #expect(runner.connectEndpoints == ["192.0.2.42:5555"])

    await coordinator.retry(identity: pixel.identity)
    let device = store.device(for: pixel.identity)
    #expect(device?.isWiFiConnected == true)
    #expect(device?.network?.serial == "192.0.2.99:5555")
    #expect(device?.operation == .readyToUnplug)
    #expect(runner.connectEndpoints == ["192.0.2.42:5555", "192.0.2.99:5555"])
}


@Test @MainActor
func customPortIsUsedForTcpipAndEndpoint() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
        { _ in ok(pixelUSBListing) },
        { _ in ok("restarting in TCP mode port: 6000\n") },
        { _ in ok("connected to 192.0.2.42:6000\n") },
        { _ in ok("TEST00000001\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner, port: 6000)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)

    let device = store.device(for: pixel.identity)!
    #expect(device.isWiFiConnected)
    #expect(device.network?.serial == "192.0.2.42:6000")
    #expect(runner.invokedCommands.contains(["-s", "TEST00000001", "tcpip", "6000"]))
    #expect(runner.connectEndpoints == ["192.0.2.42:6000"])
}
