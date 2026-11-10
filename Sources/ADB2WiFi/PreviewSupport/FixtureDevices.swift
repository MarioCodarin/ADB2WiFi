#if DEBUG
import ADB2WiFiCore
import Foundation

/// Debug-only catalog for UI work and screenshots. Never compiled into a release build.
enum FixtureDevices {
    /// Fixture catalog is opt-in. Debug builds talk to live ADB unless this is set.
    static var isEnabled: Bool {
        let value = ProcessInfo.processInfo.environment["ADB2WIFI_FIXTURES"]
        return value == "1" || value == "showcase"
    }

    static var isShowcase: Bool {
        ProcessInfo.processInfo.environment["ADB2WIFI_FIXTURES"] == "showcase"
    }

    static var catalog: [Device] { isShowcase ? showcase : makeCatalog() }

    /// A short, representative set for README screenshots.
    static var showcase: [Device] { [authorizedUSB, readyToUnplug, wifiOnlyAfterUnplug] }

    private static func makeCatalog() -> [Device] {
        [
            unauthorized,
            offline,
            authorizedUSB,
            findingAddress,
            awaitingAddress,
            readyToUnplug,
            wifiOnlyAfterUnplug,
            failedRetry,
        ]
    }

    private static var unauthorized: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000004"),
            model: "Pixel 7",
            usb: Transport(serial: "TEST00000004", state: .unauthorized)
        )
    }

    private static var offline: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000005"),
            model: "Galaxy S21",
            usb: Transport(serial: "TEST00000005", state: .offline)
        )
    }

    private static var authorizedUSB: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000001"),
            model: "Pixel 8",
            usb: Transport(serial: "TEST00000001", state: .device)
        )
    }

    private static var findingAddress: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000006"),
            model: "Pixel 8a",
            usb: Transport(serial: "TEST00000006", state: .device),
            operation: .connecting(.findingAddress)
        )
    }

    private static var awaitingAddress: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000007"),
            model: "Pixel Tablet",
            usb: Transport(serial: "TEST00000007", state: .device),
            operation: .awaitingAddress(suggested: "192.0.2.42")
        )
    }

    private static var readyToUnplug: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000008"),
            model: "Pixel 8 Pro",
            usb: Transport(serial: "TEST00000008", state: .device),
            network: Transport(serial: "192.0.2.42:5555", state: .device, verified: true),
            operation: .readyToUnplug
        )
    }

    private static var wifiOnlyAfterUnplug: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000009"),
            model: "Pixel 6",
            network: Transport(serial: "198.51.100.55:5555", state: .device, verified: true)
        )
    }

    private static var failedRetry: Device {
        Device(
            identity: DeviceIdentity(serialNo: "TEST00000010"),
            model: "Moto G",
            usb: Transport(serial: "TEST00000010", state: .device),
            operation: .failed(.missingWiFiAddress)
        )
    }
}
#endif
