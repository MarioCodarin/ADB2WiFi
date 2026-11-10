import ADB2WiFiCore

extension Device {
    /// Authorized USB Pixel used across Core tests. UI fixtures live in the executable.
    static let testUSBAuthorized = Device(
        identity: DeviceIdentity(serialNo: "TEST00000001"),
        model: "Pixel 8",
        usb: Transport(serial: "TEST00000001", state: .device)
    )
}
