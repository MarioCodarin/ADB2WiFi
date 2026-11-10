import Testing
@testable import ADB2WiFiCore

@Test func accessibilityValueIncludesUnauthorizedGuidance() {
    let device = Device(
        identity: DeviceIdentity(serialNo: "ABCDEF12"),
        model: "Pixel 7",
        usb: Transport(serial: "ABCDEF12", state: .unauthorized)
    )
    #expect(
        device.accessibilityValue
            == "USB, Unauthorized, Allow USB debugging on your phone, then try again."
    )
}

@Test func accessibilityValueIncludesOfflineGuidance() {
    let device = Device(
        identity: DeviceIdentity(serialNo: "DEADBEEF"),
        model: "Galaxy S21",
        usb: Transport(serial: "DEADBEEF", state: .offline)
    )
    #expect(
        device.accessibilityValue
            == "USB, Offline, Phone is offline. Reconnect the cable and check USB debugging."
    )
}

@Test func accessibilityValueIncludesFailedGuidance() {
    let device = Device(
        identity: DeviceIdentity(serialNo: "FAILRETRY1"),
        model: "Moto G",
        usb: Transport(serial: "FAILRETRY1", state: .device),
        operation: .failed(.unreachableEndpoint)
    )
    #expect(
        device.accessibilityValue
            == "USB, Failed, Couldn’t reach the phone. Put both devices on the same network, then retry."
    )
}

@Test func accessibilityValueForConnectingStepIsTransportAndTitle() {
    var device = Device.testUSBAuthorized
    device.operation = .connecting(.findingAddress)
    #expect(device.accessibilityValue == "USB, Finding address")
}

@Test func accessibilityValueForReadyToUnplugIncludesBothTransports() {
    let device = Device(
        identity: DeviceIdentity(serialNo: "READYUSB01"),
        model: "Pixel 8 Pro",
        usb: Transport(serial: "READYUSB01", state: .device),
        network: Transport(serial: "192.0.2.42:5555", state: .device, verified: true),
        operation: .readyToUnplug
    )
    #expect(device.accessibilityValue == "USB and Wi-Fi, 192.0.2.42:5555, Ready, unplug USB")
}

@Test func accessibilityValueForWiFiOnlyIncludesEndpoint() {
    let device = Device(
        identity: DeviceIdentity(serialNo: "WIFIONLY01"),
        model: "Pixel 6",
        network: Transport(serial: "198.51.100.55:5555", state: .device, verified: true)
    )
    #expect(device.accessibilityValue == "Wi-Fi, 198.51.100.55:5555, Wi-Fi connected")
}

@Test func accessibilityValueForIdleUSBIsTransportOnly() {
    #expect(Device.testUSBAuthorized.accessibilityValue == "USB")
}
