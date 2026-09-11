import Foundation
import Testing
@testable import ADB2WiFiCore

private let fakeADB = URL(fileURLWithPath: "/tmp/adb2wifi-test-adb")

private func ok(_ stdout: String, stderr: String = "", exitCode: Int32 = 0) -> CommandResult {
    CommandResult(exitCode: exitCode, stdout: stdout, stderr: stderr)
}

private struct MissingADBRunner: CommandRunning {
    func run(executable: URL, arguments: [String], timeout: Duration) async throws -> CommandResult {
        throw ADBError.missingExecutable
    }
}

private struct ExistsSet: FileChecking {
    var paths: Set<String>
    init(_ paths: [String]) { self.paths = Set(paths) }
    func fileExists(atPath path: String) -> Bool { paths.contains(path) }
    func isExecutableFile(atPath path: String) -> Bool { paths.contains(path) }
}

private final class MutableFiles: FileChecking, @unchecked Sendable {
    var paths: Set<String>
    init(_ paths: [String]) { self.paths = Set(paths) }
    func fileExists(atPath path: String) -> Bool { paths.contains(path) }
    func isExecutableFile(atPath path: String) -> Bool { paths.contains(path) }
}

private final class RecordingClock: Sleeping, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Duration] = []
    var durations: [Duration] {
        lock.withLock { stored }
    }

    func sleep(for duration: Duration) async throws {
        lock.withLock { stored.append(duration) }
        try await Task.sleep(for: .seconds(3_600))
    }
}

@MainActor
private func makeStore(
    runner: any CommandRunning,
    clock: any Sleeping = ImmediateClock(),
    fileManager: any FileChecking = ExistsSet([fakeADB.path]),
    settings: AppSettings? = nil
) -> DeviceStore {
    let settings = settings ?? {
        let created = AppSettings(storage: InMemoryDefaults())
        created.adbPathOverride = fakeADB
        return created
    }()
    return DeviceStore(
        settings: settings,
        runner: runner,
        clock: clock,
        fileManager: fileManager,
        pathEnv: "",
        environment: [:],
        homeDirectory: URL(fileURLWithPath: "/tmp")
    )
}

@Test @MainActor
func refreshUsesDevicesDashLAndSurfacesMissingADB() async {
    let settings = AppSettings(storage: InMemoryDefaults())
    let store = DeviceStore(settings: settings, runner: MissingADBRunner(), clock: ImmediateClock())
    await store.refresh()
    #expect(store.globalError == .missingADB)
    #expect(store.devices.isEmpty)
}

@Test @MainActor
func refreshListsPhysicalDevicesUsingDevicesDashL() async {
    let listing = """
    List of devices attached
    TEST00000001         device usb:1-1 product:shiba model:Pixel_8 device:shiba transport_id:2
    192.0.2.42:5555      device product:shiba model:Pixel_8 device:shiba transport_id:3
    emulator-5554          device product:sdk model:sdk
    TEST00000002            device usb:2-1 product:husky model:Pixel_8
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok("TEST00000001\n") },
        { _ in ok("TEST00000002\n") },
        { _ in ok("Pixel 8\n") },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()

    #expect(store.globalError == nil)
    #expect(store.devices.count == 2)
    #expect(runner.calls[0].arguments == ["devices", "-l"])
    #expect(runner.calls.map(\.arguments).contains(["-s", "emulator-5554", "shell", "getprop ro.serialno"]) == false)

    let pixel = store.devices.first { $0.identity.serialNo == "TEST00000001" }!
    #expect(pixel.usb?.serial == "TEST00000001")
    #expect(pixel.network?.serial == "192.0.2.42:5555")
    #expect(pixel.model == "Pixel 8")
    #expect(store.devices.contains { $0.identity.serialNo == "TEST00000002" })
}

@Test @MainActor
func refreshShowsUnauthorizedWithoutShell() async {
    let listing = """
    List of devices attached
    ABCDEF12               unauthorized usb:1-1 transport_id:4
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()

    #expect(store.globalError == nil)
    #expect(store.devices.count == 1)
    #expect(store.devices[0].identity.serialNo == "ABCDEF12")
    #expect(store.devices[0].usb?.state == .unauthorized)
    #expect(runner.calls.map(\.arguments) == [["devices", "-l"]])
}

@Test @MainActor
func refreshKeepsDevicesWhenADBGoesMissing() async {
    let listing = """
    List of devices attached
    TEST00000001         device usb:1-1 product:shiba model:Pixel_8
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
    ])
    let files = MutableFiles([fakeADB.path])
    let settings = AppSettings(storage: InMemoryDefaults())
    settings.adbPathOverride = fakeADB
    let store = makeStore(runner: runner, fileManager: files, settings: settings)
    await store.refresh()
    #expect(store.devices.count == 1)

    files.paths = []
    await store.refresh()
    #expect(store.globalError == .missingADB)
    #expect(store.devices.count == 1)
    #expect(store.devices[0].identity.serialNo == "TEST00000001")
}

@Test @MainActor
func refreshCachesModelAcrossPollsThatOmitModel() async {
    let withModel = """
    List of devices attached
    ABC                    device usb:1-1 model:Pixel_8
    """
    let withoutModel = """
    List of devices attached
    ABC                    device usb:1-1
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(withModel) },
        { _ in ok("ABC\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(withoutModel) },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()
    #expect(store.devices.map(\.model) == ["Pixel 8"])
    await store.refresh()
    #expect(store.devices.map(\.model) == ["Pixel 8"])
    #expect(runner.calls.map(\.arguments) == [
        ["devices", "-l"],
        ["-s", "ABC", "shell", "getprop ro.serialno"],
        ["-s", "ABC", "shell", "getprop ro.product.model"],
        ["devices", "-l"],
    ])
}

@Test @MainActor
func updateWritesOperationAndDeviceLookup() async {
    let listing = """
    List of devices attached
    TEST00000001         device usb:1-1 model:Pixel_8
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()

    var device = store.devices[0]
    device.operation = .connecting(.findingAddress)
    store.update(device)

    let found = store.device(for: DeviceIdentity(serialNo: "TEST00000001"))
    #expect(found?.operation == .connecting(.findingAddress))
}

@Test @MainActor
func refreshMapsRunnerFailureToADBOutput() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok("not a device list", exitCode: 1) },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()
    #expect(store.devices.isEmpty)
    guard case .adbOutput = store.globalError else {
        Issue.record("expected adbOutput, got \(String(describing: store.globalError))")
        return
    }
}

@Test @MainActor
func refreshRequeriesIdentityWhenHostPortMovesToANewPhone() async {
    let endpoint = "192.0.2.42:5555"
    let networkListing = """
    List of devices attached
    \(endpoint)      device product:shiba model:Pixel_8
    """
    let emptyListing = """
    List of devices attached
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(networkListing) },
        { _ in ok("PHONEA\n") },
        { _ in ok("Pixel 8\n") },
        { _ in ok(emptyListing) },
        { _ in ok(networkListing) },
        { _ in ok("PHONEB\n") },
        { _ in ok("Pixel 9\n") },
    ])
    let store = makeStore(runner: runner)

    await store.refresh()
    #expect(store.devices.map(\.identity.serialNo) == ["PHONEA"])

    await store.refresh()
    #expect(store.devices.isEmpty)

    await store.refresh()
    #expect(store.devices.map(\.identity.serialNo) == ["PHONEB"])
    #expect(store.devices[0].model == "Pixel 9")
    #expect(store.devices[0].network?.serial == endpoint)
    let serialNoCalls = runner.calls.filter { $0.arguments == ["-s", endpoint, "shell", "getprop ro.serialno"] }
    #expect(serialNoCalls.count == 2)
}

@Test @MainActor
func refreshDoesNotApplyDevicesWhenSerialNoIsCancelled() async {
    let listing = """
    List of devices attached
    TEST00000001         device usb:1-1 model:Pixel_8
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
        { _ in throw CancellationError() },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()
    #expect(store.devices.isEmpty)
    #expect(store.globalError == nil)
}

@Test @MainActor
func refreshDoesNotApplyDevicesWhenModelIsCancelled() async {
    let listing = """
    List of devices attached
    TEST00000001         device usb:1-1 model:Pixel_8
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
        { _ in ok("TEST00000001\n") },
        { _ in throw CancellationError() },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()
    #expect(store.devices.isEmpty)
    #expect(store.globalError == nil)
}

@Test @MainActor
func refreshDoesNotFetchVersion() async {
    let listing = """
    List of devices attached
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
    ])
    let store = makeStore(runner: runner)
    await store.refresh()
    #expect(runner.calls.map(\.arguments) == [["devices", "-l"]])
    #expect(store.adbVersion == nil)
}

@Test @MainActor
func refreshVersionFetchesAdbVersion() async {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok("Android Debug Bridge version 37.0.1\n") },
    ])
    let store = makeStore(runner: runner)
    await store.refreshVersion()
    #expect(store.adbVersion == "37.0.1")
    #expect(runner.calls.map(\.arguments) == [["version"]])
}

@Test @MainActor
func refreshVersionClearsWhenADBMissing() async {
    let settings = AppSettings(storage: InMemoryDefaults())
    let store = DeviceStore(settings: settings, runner: MissingADBRunner(), clock: ImmediateClock())
    await store.refreshVersion()
    #expect(store.adbVersion == nil)
}

@Test @MainActor
func startPollsAtTwoSecondsOpenAndTenSecondsClosed() async {
    let listing = """
    List of devices attached
    """
    let runner = FakeCommandRunner(handlers: [
        { _ in ok(listing) },
        { _ in ok(listing) },
    ])
    let clock = RecordingClock()
    let store = makeStore(runner: runner, clock: clock)
    store.isPopoverOpen = true
    store.start()

    let started = ContinuousClock.now
    while clock.durations.isEmpty && ContinuousClock.now - started < .seconds(1) {
        try? await Task.sleep(for: .milliseconds(5))
    }
    #expect(clock.durations.first == .seconds(2))

    store.isPopoverOpen = false
    store.stop()
    store.start()
    let restarted = ContinuousClock.now
    while clock.durations.count < 2 && ContinuousClock.now - restarted < .seconds(1) {
        try? await Task.sleep(for: .milliseconds(5))
    }
    #expect(clock.durations.last == .seconds(10))
    store.stop()
}
