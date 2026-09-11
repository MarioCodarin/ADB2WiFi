public struct DeviceIdentity: Hashable, Sendable {
    public var serialNo: String
    public var shortSerial: String {
        serialNo.count > 8 ? String(serialNo.suffix(8)) : serialNo
    }
    public init(serialNo: String) { self.serialNo = serialNo }
}

public enum TransportKind: String, Sendable { case usb, network }

public enum Availability: String, Sendable {
    case device, unauthorized, offline, unknown
}

public enum ConnectionStep: String, Sendable {
    case findingAddress, enablingWifi, connecting, verifying
}

public enum OperationState: Equatable, Sendable {
    case idle
    case connecting(ConnectionStep)
    case awaitingAddress(suggested: String?)
    case readyToUnplug
    case failed(AppError)

    public var isAwaitingAddress: Bool {
        if case .awaitingAddress = self { return true }
        return false
    }
}

public struct Transport: Equatable, Sendable {
    public var serial: String
    public var state: Availability
    public var verified: Bool
    public init(serial: String, state: Availability, verified: Bool = false) {
        self.serial = serial
        self.state = state
        self.verified = verified
    }
}

public struct Device: Identifiable, Equatable, Sendable {
    public var id: DeviceIdentity { identity }
    public var identity: DeviceIdentity
    public var model: String
    public var usb: Transport?
    public var network: Transport?
    public var operation: OperationState
    public var isWiFiConnected: Bool { network?.verified == true && network?.state == .device }
    public init(identity: DeviceIdentity, model: String, usb: Transport? = nil,
                network: Transport? = nil, operation: OperationState = .idle) {
        self.identity = identity
        self.model = model
        self.usb = usb
        self.network = network
        self.operation = operation
    }
}

public enum AppError: Equatable, Error, Sendable {
    case missingADB
    case authorizationPending
    case deviceOffline
    case missingWiFiAddress
    case unreachableEndpoint
    case usbRemoved
    case timeout
    case identityMismatch
    case adbOutput(String)
    public var guidance: String {
        switch self {
        case .missingADB:
            "ADB was not found. Choose the executable in Settings. Homebrew installs it at /opt/homebrew/bin/adb."
        case .authorizationPending:
            "Authorize USB debugging on the phone, then tap Retry."
        case .deviceOffline:
            "The device is offline. Replug USB and check USB debugging."
        case .missingWiFiAddress:
            "No Wi-Fi IPv4 address found. Join a network, or enter the address."
        case .unreachableEndpoint:
            "Could not reach the phone over Wi-Fi. Same network? Then Retry."
        case .usbRemoved:
            "USB was unplugged before Wi-Fi ADB was enabled. Replug and Retry."
        case .timeout:
            "Timed out waiting for Wi-Fi ADB. Retry while USB is still connected."
        case .identityMismatch:
            "Connected endpoint is a different device. Disconnect it and Retry."
        case .adbOutput(let output):
            output.isEmpty ? "ADB returned an unexpected error." : output
        }
    }
}

public struct ADBTransport: Equatable, Sendable {
    public var serial: String
    public var state: Availability
    public var product: String?
    public var model: String?
    public var usb: String?
    public var transportID: String?
    public var isEmulator: Bool { serial.hasPrefix("emulator-") }
    public var isNetwork: Bool {
        serial.contains(":") || serial.contains("._adb-tls-connect._tcp")
    }
    public init(serial: String, state: Availability, product: String? = nil,
                model: String? = nil, usb: String? = nil, transportID: String? = nil) {
        self.serial = serial; self.state = state; self.product = product
        self.model = model; self.usb = usb; self.transportID = transportID
    }
}

extension Device {
    /// Authorized USB Pixel used by Core tests. Extra UI states live in the executable.
    public static let fixtureUSBAuthorized = Device(
        identity: DeviceIdentity(serialNo: "TEST00000001"),
        model: "Pixel 8",
        usb: Transport(serial: "TEST00000001", state: .device)
    )
}
