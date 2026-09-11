import Foundation
import Testing
@testable import ADB2WiFiCore

private let adbURL = URL(fileURLWithPath: "/opt/homebrew/bin/adb")

private func ok(_ stdout: String, stderr: String = "", exitCode: Int32 = 0) -> CommandResult {
    CommandResult(exitCode: exitCode, stdout: stdout, stderr: stderr)
}

@Test func devicesInvokesDevicesDashLWithoutSerial() async throws {
    let stdout = """
    List of devices attached
    TEST00000001         device usb:1-1 product:shiba model:Pixel_8 device:shiba transport_id:2
    """
    let runner = FakeCommandRunner(handlers: [{ _ in ok(stdout) }])
    let client = ADBClient(executable: adbURL, runner: runner)

    let transports = try await client.devices()

    #expect(runner.calls.count == 1)
    #expect(runner.calls[0].executable == adbURL)
    #expect(runner.calls[0].arguments == ["devices", "-l"])
    #expect(runner.calls[0].timeout == .seconds(8))
    #expect(transports.count == 1)
    #expect(transports[0].serial == "TEST00000001")
    #expect(transports[0].model == "Pixel 8")
}

@Test func devicesListingUnauthorizedDoesNotThrow() async throws {
    let stdout = """
    List of devices attached
    ABCDEF12               unauthorized usb:1-1 transport_id:4
    """
    let runner = FakeCommandRunner(handlers: [{ _ in ok(stdout) }])
    let client = ADBClient(executable: adbURL, runner: runner)

    let transports = try await client.devices()
    #expect(transports.map(\.serial) == ["ABCDEF12"])
    #expect(transports[0].state == .unauthorized)
}

@Test func tcpipTargetsSerialAsFirstArguments() async throws {
    let runner = FakeCommandRunner(handlers: [{ _ in ok("restarting in TCP mode port: 5555\n") }])
    let client = ADBClient(executable: adbURL, runner: runner)

    try await client.tcpip(serial: "USB123", port: 5555)

    #expect(runner.calls.count == 1)
    #expect(runner.calls[0].arguments == ["-s", "USB123", "tcpip", "5555"])
    #expect(runner.calls[0].timeout == .seconds(8))
}

@Test func connectSucceedsOnConnectedTo() async throws {
    let runner = FakeCommandRunner(handlers: [{ _ in ok("connected to 192.0.2.42:5555\n") }])
    let client = ADBClient(executable: adbURL, runner: runner)

    try await client.connect(endpoint: "192.0.2.42:5555", timeout: .seconds(12))

    #expect(runner.calls[0].arguments == ["connect", "192.0.2.42:5555"])
    #expect(runner.calls[0].timeout == .seconds(12))
}

@Test func connectSucceedsOnAlreadyConnectedTo() async throws {
    let runner = FakeCommandRunner(handlers: [{ _ in
        ok("already connected to 192.0.2.42:5555\n")
    }])
    let client = ADBClient(executable: adbURL, runner: runner)

    try await client.connect(endpoint: "192.0.2.42:5555")
}

@Test func connectThrowsUnparseableOnFailedToConnectDespiteExitZero() async {
    let stdout = "failed to connect to 192.0.2.42:5555"
    let runner = FakeCommandRunner(handlers: [{ _ in ok(stdout, exitCode: 0) }])
    let client = ADBClient(executable: adbURL, runner: runner)

    await #expect(throws: ADBError.unparseable(stdout)) {
        try await client.connect(endpoint: "192.0.2.42:5555")
    }
}

@Test func shellPassesCommandAsSeparateArgument() async throws {
    let runner = FakeCommandRunner(handlers: [{ _ in ok("TEST00000001\n") }])
    let client = ADBClient(executable: adbURL, runner: runner)

    let output = try await client.shell(serial: "USB123", command: "getprop ro.serialno")

    #expect(output == "TEST00000001\n")
    #expect(runner.calls[0].arguments == ["-s", "USB123", "shell", "getprop ro.serialno"])
    #expect(runner.calls[0].timeout == .seconds(8))
}

@Test func serialNoAndModelUseGetprop() async throws {
    let runner = FakeCommandRunner(handlers: [
        { _ in ok("TEST00000001\n") },
        { _ in ok("Pixel 8\n") },
    ])
    let client = ADBClient(executable: adbURL, runner: runner)

    #expect(try await client.serialNo(serial: "USB123") == "TEST00000001")
    #expect(try await client.model(serial: "USB123") == "Pixel 8")
    #expect(runner.calls.map(\.arguments) == [
        ["-s", "USB123", "shell", "getprop ro.serialno"],
        ["-s", "USB123", "shell", "getprop ro.product.model"],
    ])
}

@Test(arguments: [
    (stdout: "error: device unauthorized.\n", stderr: ""),
    (stdout: "", stderr: "error: device unauthorized.\n"),
])
func unauthorizedOutputThrowsUnauthorized(stdout: String, stderr: String) async {
    let runner = FakeCommandRunner(handlers: [{ _ in
        ok(stdout, stderr: stderr, exitCode: 1)
    }])
    let client = ADBClient(executable: adbURL, runner: runner)

    await #expect(throws: ADBError.unauthorized) {
        try await client.shell(serial: "ABCDEF12", command: "getprop ro.serialno")
    }
}

@Test func versionParsesADBVersionLine() async throws {
    let stdout = """
    Android Debug Bridge version 1.0.41
    Version 37.0.1-12932953
    Installed as /opt/homebrew/bin/adb
    Running on Darwin 24.3.0 (arm64)
    """
    let runner = FakeCommandRunner(handlers: [{ _ in ok(stdout) }])
    let client = ADBClient(executable: adbURL, runner: runner)

    #expect(try await client.version() == "1.0.41")
    #expect(runner.calls[0].arguments == ["version"])
    #expect(runner.calls[0].timeout == .seconds(8))
}

@Test func disconnectTargetsEndpoint() async throws {
    let runner = FakeCommandRunner(handlers: [{ _ in ok("disconnected 192.0.2.42:5555\n") }])
    let client = ADBClient(executable: adbURL, runner: runner)

    try await client.disconnect(endpoint: "192.0.2.42:5555")

    #expect(runner.calls[0].arguments == ["disconnect", "192.0.2.42:5555"])
    #expect(runner.calls[0].timeout == .seconds(8))
}

@Test func wifiAddressesShellsIpDashODash4AddrShowUp() async throws {
    let stdout = """
    1: lo    inet 127.0.0.1/8 ...
    12: wlan0    inet 192.0.2.42/24 ...
    14: rmnet_data0 inet 10.132.4.8/30 ...
    """
    let runner = FakeCommandRunner(handlers: [{ _ in ok(stdout) }])
    let client = ADBClient(executable: adbURL, runner: runner)

    let addresses = try await client.wifiAddresses(serial: "USB123")

    #expect(runner.calls.count == 1)
    #expect(runner.calls[0].arguments == ["-s", "USB123", "shell", "ip -o -4 addr show up"])
    #expect(runner.calls[0].timeout == .seconds(8))
    #expect(addresses == [WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42")])
}
