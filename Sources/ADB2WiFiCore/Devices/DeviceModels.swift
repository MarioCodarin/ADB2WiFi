public struct DeviceIdentity: Hashable, Sendable {
    public var serialNo: String
    public var shortSerial: String {
        serialNo.count > 8 ? String(serialNo.suffix(8)) : serialNo
    }
    public init(serialNo: String) { self.serialNo = serialNo }
}

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

    /// A connection attempt is running; poll faster so the card and USB state stay fresh.
    public var isInFlight: Bool {
        if case .connecting = self { return true }
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
    /// VoiceOver value: transport plus operation, including on-screen guidance.
    public var accessibilityValue: String {
        [accessibilityTransport, network?.serial, accessibilityOperation]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var accessibilityTransport: String? {
        switch (usb != nil, network != nil) {
        case (true, true): "USB and Wi-Fi"
        case (true, false): "USB"
        case (false, true): "Wi-Fi"
        case (false, false): nil
        }
    }

    private var accessibilityOperation: String? {
        switch operation {
        case .idle:
            if usb?.state == .unauthorized {
                return "Unauthorized, \(AppError.authorizationPending.displayedGuidance)"
            }
            if usb?.state == .offline {
                return "Offline, \(AppError.deviceOffline.displayedGuidance)"
            }
            if isWiFiConnected { return "Wi-Fi connected" }
            return nil
        case .connecting(let step):
            return step.title
        case .awaitingAddress:
            return "Enter IPv4 address"
        case .readyToUnplug:
            return "Ready, unplug USB"
        case .failed(let error):
            return "Failed, \(error.displayedGuidance)"
        }
    }
}

extension ConnectionStep {
    public var title: String {
        switch self {
        case .findingAddress: "Finding address"
        case .enablingWifi: "Enabling Wi-Fi"
        case .connecting: "Connecting"
        case .verifying: "Verifying"
        }
    }
}
