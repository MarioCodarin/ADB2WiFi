import ADB2WiFiCore
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registered, but macOS is waiting for the user to approve the login item.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            Log.settings.notice("launch at login registered")
        } else {
            try SMAppService.mainApp.unregister()
            Log.settings.notice("launch at login unregistered")
        }
    }
}
