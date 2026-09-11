import Foundation
import Testing
@testable import ADB2WiFiCore

private let fakeADB = URL(fileURLWithPath: "/tmp/adb2wifi-test-adb")
private let pixel = Device.fixtureUSBAuthorized
private let samsungIdentity = DeviceIdentity(serialNo: "TEST00000002")

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
private func makeHarness(runner: FakeCommandRunner) -> (DeviceStore, ConnectionCoordinator) {
    let settings = AppSettings(storage: InMemoryDefaults())
    settings.adbPathOverride = fakeADB
    let store = DeviceStore(
        settings: settings,
        runner: runner,
        clock: ImmediateClock(),
        fileManager: ExistsSet([fakeADB.path]),
        pathEnv: "",
        environment: [:],
        homeDirectory: URL(fileURLWithPath: "/tmp")
    )
    let client = ADBClient(executable: fakeADB, runner: runner)
    let coordinator = ConnectionCoordinator(store: store, client: client, clock: ImmediateClock())
    return (store, coordinator)
}

@Test @MainActor
func oneClickConnectsAndVerifiesIdentity() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(pixelUSBListing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(wlan0Only) },
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
        { _ in ok("restarting in TCP mode port: 5555\n") },
        { _ in ok("connected to 192.0.2.42:5555\n") },
        { _ in ok("OTHER_SERIAL\n") },
    ])
    let (store, coordinator) = makeHarness(runner: runner)
    await store.refresh()

    await coordinator.connect(identity: pixel.identity)
    #expect(store.device(for: pixel.identity)?.isWiFiConnected == false)
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
