import AppKit

/// AppKit entry point. A SwiftUI `App` scene would create a hidden Settings window on
/// newer SDKs; the entire UI is an `NSStatusItem` popover, so no scene is needed.
@main
enum ADB2WiFiMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
