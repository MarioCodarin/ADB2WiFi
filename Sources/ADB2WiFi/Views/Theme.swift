import AppKit
import SwiftUI

enum Theme {
    static let popoverWidth: CGFloat = 340
    static let corner: CGFloat = 12

    /// One accent, used only for the primary action and the mark. Everything else is
    /// system material and typography, which keeps the popover quiet in both appearances.
    static let accent = Color(red: 0.04, green: 0.42, blue: 0.98)
    static let success = Color(red: 0.10, green: 0.62, blue: 0.35)
    static let warning = Color(red: 0.90, green: 0.52, blue: 0.10)

    static let cardFill = Color(nsColor: .controlBackgroundColor).opacity(0.55)
    static let cardStroke = Color.primary.opacity(0.08)
    static let hairline = Color.primary.opacity(0.08)
    static let iconFill = accent.opacity(0.12)
}

/// `State` the property wrapper. Newer SDKs also ship a `@State` macro whose plugin is
/// absent from a Command Line Tools-only toolchain; a typealias never resolves to the macro.
/// This keeps `swift build` working without Xcode while preserving the familiar syntax.
typealias ViewState<Value> = State<Value>

enum DebugFlags {
    static var showSettingsOnLaunch: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ADB2WIFI_SHOW_SETTINGS"] == "1"
        #else
        false
        #endif
    }

    static var lightAppearance: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ADB2WIFI_APPEARANCE"] == "light"
        #else
        false
        #endif
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static let repository = URL(string: "https://github.com/MarioCodarin/ADB2WiFi")!
}
