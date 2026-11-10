import ADB2WiFiCore
import UserNotifications

@MainActor
enum ReadyNotifier {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.app.error("notification authorization failed error=\(String(describing: error), privacy: .private)")
            return false
        }
    }

    static func post(device: Device) {
        let content = UNMutableNotificationContent()
        let model = device.model.isEmpty ? "Your phone" : device.model
        content.title = "\(model) is on Wi-Fi"
        content.body = "Unplug USB. The connection stays up."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ready-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                Log.app.notice("ready notification posted")
            } catch {
                Log.app.error("ready notification failed error=\(String(describing: error), privacy: .private)")
            }
        }
    }
}
