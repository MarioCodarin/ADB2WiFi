import Testing
@testable import ADB2WiFiCore

private let attachedFixture = """
List of devices attached
TEST00000002            device usb:2-1 product:p3sxxx model:SM_G998B device:p3s transport_id:1
TEST00000001         device usb:1-1 product:shiba model:Pixel_8 device:shiba transport_id:2
emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:3
ABCDEF12               unauthorized usb:1-1 transport_id:4
DEADBEEF               offline usb:1-2 transport_id:5
192.0.2.42:5555      device product:shiba model:Pixel_8 device:shiba transport_id:6
adb-TEST00000003-EonbQL._adb-tls-connect._tcp device product:a10ub model:SM_A105M transport_id:7
"""

@Test func parsesSerialStateModelUsbAndTransportID() {
    let transports = DeviceListParser.parse(attachedFixture)
    #expect(transports.count == 7)

    let samsung = transports.first { $0.serial == "TEST00000002" }!
    #expect(samsung.state == .device)
    #expect(samsung.product == "p3sxxx")
    #expect(samsung.model == "SM G998B")
    #expect(samsung.usb == "2-1")
    #expect(samsung.transportID == "1")
    #expect(samsung.isEmulator == false)
    #expect(samsung.isNetwork == false)

    let pixel = transports.first { $0.serial == "TEST00000001" }!
    #expect(pixel.state == .device)
    #expect(pixel.product == "shiba")
    #expect(pixel.model == "Pixel 8")
    #expect(pixel.usb == "1-1")
    #expect(pixel.transportID == "2")
}

@Test func marksEmulatorTransport() {
    let emu = DeviceListParser.parse(attachedFixture).first { $0.serial == "emulator-5554" }!
    #expect(emu.isEmulator)
    #expect(emu.isNetwork == false)
    #expect(emu.state == .device)
    #expect(emu.model == "sdk gphone64 arm64")
}

@Test func marksNetworkTransports() {
    let transports = DeviceListParser.parse(attachedFixture)

    let ip = transports.first { $0.serial == "192.0.2.42:5555" }!
    #expect(ip.isNetwork)
    #expect(ip.isEmulator == false)
    #expect(ip.state == .device)
    #expect(ip.model == "Pixel 8")
    #expect(ip.transportID == "6")

    let mdns = transports.first { $0.serial == "adb-TEST00000003-EonbQL._adb-tls-connect._tcp" }!
    #expect(mdns.isNetwork)
    #expect(mdns.isEmulator == false)
    #expect(mdns.product == "a10ub")
    #expect(mdns.model == "SM A105M")
    #expect(mdns.transportID == "7")
}

@Test func parsesUnauthorizedAndOffline() {
    let transports = DeviceListParser.parse(attachedFixture)

    let unauthorized = transports.first { $0.serial == "ABCDEF12" }!
    #expect(unauthorized.state == .unauthorized)
    #expect(unauthorized.usb == "1-1")
    #expect(unauthorized.transportID == "4")

    let offline = transports.first { $0.serial == "DEADBEEF" }!
    #expect(offline.state == .offline)
    #expect(offline.usb == "1-2")
    #expect(offline.transportID == "5")
}

@Test func ignoresHeaderAndDaemonNoise() {
    let stdout = """
    * daemon not running. starting it now on port 5037 *
    * daemon started successfully *
    List of devices attached
    TEST00000001         device usb:1-1 product:shiba model:Pixel_8 device:shiba transport_id:2
    """
    let transports = DeviceListParser.parse(stdout)
    #expect(transports.map(\.serial) == ["TEST00000001"])
    #expect(transports[0].model == "Pixel 8")
}

@Test func emptyListAfterHeaderIsEmpty() {
    #expect(DeviceListParser.parse("List of devices attached\n") == [])
    #expect(DeviceListParser.parse("List of devices attached\n\n") == [])
}
