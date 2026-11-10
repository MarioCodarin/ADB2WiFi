import ADB2WiFiCore
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
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
