public enum AppError: Equatable, Error, Sendable {
    case missingADB
    case authorizationPending
    case deviceOffline
    case missingWiFiAddress
    case unreachableEndpoint
    case usbRemoved
    case timeout
    case identityMismatch
    case adbLaunchFailed(String)
    case adbOutput(String)

    /// Short title for compact status rows.
    public var title: String {
        switch self {
        case .missingADB: "ADB not found"
        case .authorizationPending: "Authorization needed"
        case .deviceOffline: "Phone offline"
        case .missingWiFiAddress: "No Wi-Fi address"
        case .unreachableEndpoint: "Can’t reach phone"
        case .usbRemoved: "Cable unplugged"
        case .timeout: "Timed out"
        case .identityMismatch: "Wrong device"
        case .adbLaunchFailed: "ADB failed"
        case .adbOutput: "ADB error"
        }
    }

    public var guidance: String {
        switch self {
        case .missingADB:
            "ADB wasn’t found. Install Android Platform Tools or choose your adb in Settings."
        case .authorizationPending:
            "Allow USB debugging on your phone, then try again."
        case .deviceOffline:
            "Phone is offline. Reconnect the cable and check USB debugging."
        case .missingWiFiAddress:
            "No Wi-Fi address found. Join a Wi-Fi network, or enter the address."
        case .unreachableEndpoint:
            "Couldn’t reach the phone. Put both devices on the same network, then retry."
        case .usbRemoved:
            "USB was unplugged too early. Reconnect the cable and try again."
        case .timeout:
            "ADB timed out. Keep USB connected and try again."
        case .identityMismatch:
            "That endpoint is a different phone. Disconnect it and try again."
        case .adbLaunchFailed:
            "Couldn’t launch ADB. Reinstall Android Platform Tools or choose another adb."
        case .adbOutput(let output):
            output.isEmpty ? "ADB returned an unexpected error." : output
        }
    }

    public var displayedGuidance: String {
        guidance.isEmpty ? "Connection failed." : guidance
    }

    /// True when the fix is to open the ADB setup screen rather than retry the phone.
    public var needsADBSetup: Bool {
        switch self {
        case .missingADB, .adbLaunchFailed: true
        default: false
        }
    }
}
