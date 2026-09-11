import Testing
@testable import ADB2WiFiCore

@Test func shortenedSerialKeepsLastEight() {
    let id = DeviceIdentity(serialNo: "TEST00000001")
    #expect(id.shortSerial == "00000001")
}

@Test func shortSerialPassthroughWhenAlreadyShort() {
    let id = DeviceIdentity(serialNo: "ABC123")
    #expect(id.shortSerial == "ABC123")
}

@Test func wifiConnectedRequiresVerifiedNetworkTransport() {
    var device = Device.fixtureUSBAuthorized
    #expect(device.isWiFiConnected == false)
    device.network = .init(serial: "192.0.2.42:5555", state: .device, verified: true)
    #expect(device.isWiFiConnected == true)
}
