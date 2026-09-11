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
            == "USB, Unauthorized, Authorize USB debugging on the phone, then tap Retry."
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
            == "USB, Offline, The device is offline. Replug USB and check USB debugging."
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
            == "USB, Failed, Could not reach the phone over Wi-Fi. Same network? Then Retry."
    )
}

@Test func accessibilityValueForConnectingStepIsTransportAndTitle() {
    var device = Device.fixtureUSBAuthorized
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
    #expect(device.accessibilityValue == "USB and Wi-Fi, Ready, unplug USB")
}

@Test func accessibilityValueForIdleUSBIsTransportOnly() {
    #expect(Device.fixtureUSBAuthorized.accessibilityValue == "USB")
}
