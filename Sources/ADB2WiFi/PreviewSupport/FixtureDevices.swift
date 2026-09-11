import ADB2WiFiCore
import Foundation

enum FixtureDevices {
    /// DEBUG builds always show fixtures. Release builds require `ADB2WIFI_FIXTURES=1`.
    /// Task 1 has no live DeviceStore, so the popover uses `catalog` regardless.
    static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment["ADB2WIFI_FIXTURES"] == "1" {
            return true
        }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static let empty: [Device] = []

    static var catalog: [Device] { makeCatalog() }

    private static func makeCatalog() -> [Device] {
        [
            unauthorized,
            offline,
            .fixtureUSBAuthorized,
            findingAddress,
            enablingWifi,
            connecting,
            verifying,
            awaitingAddress,
            readyToUnplug,
            wifiOnlyAfterUnplug,
            failedRetry,
        ]
    }

    private static var unauthorized: Device {
        Device(
            identity: DeviceIdentity(serialNo: "ABCDEF12"),
            model: "Pixel 7",
            usb: Transport(serial: "ABCDEF12", state: .unauthorized)
        )
    }

    private static var offline: Device {
        Device(
            identity: DeviceIdentity(serialNo: "DEADBEEF"),
            model: "Galaxy S21",
            usb: Transport(serial: "DEADBEEF", state: .offline)
        )
    }

    private static var findingAddress: Device {
        Device(
            identity: DeviceIdentity(serialNo: "FINDADDR01"),
            model: "Pixel 8a",
            usb: Transport(serial: "FINDADDR01", state: .device),
            operation: .connecting(.findingAddress)
        )
    }

    private static var enablingWifi: Device {
        Device(
            identity: DeviceIdentity(serialNo: "ENABLEWIFI"),
            model: "Pixel 9",
            usb: Transport(serial: "ENABLEWIFI", state: .device),
            operation: .connecting(.enablingWifi)
        )
    }

    private static var connecting: Device {
        Device(
            identity: DeviceIdentity(serialNo: "CONNECTME1"),
            model: "Galaxy S24",
            usb: Transport(serial: "CONNECTME1", state: .device),
            operation: .connecting(.connecting)
        )
    }

    private static var verifying: Device {
        Device(
            identity: DeviceIdentity(serialNo: "VERIFYME01"),
            model: "Pixel Fold",
            usb: Transport(serial: "VERIFYME01", state: .device),
            operation: .connecting(.verifying)
        )
    }

    private static var awaitingAddress: Device {
        Device(
            identity: DeviceIdentity(serialNo: "NEEDADDR01"),
            model: "Pixel Tablet",
            usb: Transport(serial: "NEEDADDR01", state: .device),
            operation: .awaitingAddress(suggested: "192.0.2.42")
        )
    }

    private static var readyToUnplug: Device {
        Device(
            identity: DeviceIdentity(serialNo: "READYUSB01"),
            model: "Pixel 8 Pro",
            usb: Transport(serial: "READYUSB01", state: .device),
            network: Transport(serial: "192.0.2.42:5555", state: .device, verified: true),
            operation: .readyToUnplug
        )
    }

    private static var wifiOnlyAfterUnplug: Device {
        Device(
            identity: DeviceIdentity(serialNo: "WIFIONLY01"),
            model: "Pixel 6",
            network: Transport(serial: "198.51.100.55:5555", state: .device, verified: true)
        )
    }

    private static var failedRetry: Device {
        Device(
            identity: DeviceIdentity(serialNo: "FAILRETRY1"),
            model: "Moto G",
            usb: Transport(serial: "FAILRETRY1", state: .device),
            operation: .failed(.missingWiFiAddress)
        )
    }
}
