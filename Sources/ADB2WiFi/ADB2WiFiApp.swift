import SwiftUI

@main
struct ADB2WiFiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Required Scene; chrome is the status item popover, not a window.
        Settings {
            EmptyView()
        }
    }
}
