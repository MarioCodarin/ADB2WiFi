import ADB2WiFiCore
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: DeviceStore?
    private var coordinator: ConnectionCoordinator?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        #if DEBUG
        if ProcessInfo.processInfo.environment["ADB2WIFI_APPEARANCE"] == "light" {
            NSApp.appearance = NSAppearance(named: .aqua)
        } else if ProcessInfo.processInfo.environment["ADB2WIFI_APPEARANCE"] == "dark" {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        #endif
        Log.app.notice(
            "launch version=\(AppInfo.version, privacy: .public) macOS=\(ProcessInfo.processInfo.operatingSystemVersionString, privacy: .public)"
        )

        #if DEBUG
        if let output = ProcessInfo.processInfo.environment["ADB2WIFI_SNAPSHOT"] {
            SnapshotRenderer.render(to: output)
            NSApp.terminate(nil)
            return
        }
        #endif

        let settings = AppSettings()
        let runner = ProcessCommandRunner()
        let store = DeviceStore(settings: settings, runner: runner)
        let coordinator = ConnectionCoordinator(store: store, clientProvider: { store.makeClient() })

        self.store = store
        self.coordinator = coordinator

        statusItemController = StatusItemController(
            settings: settings,
            store: store,
            coordinator: coordinator,
            onQuit: { [weak self] in self?.quit() }
        )

        observeWorkspace()

        #if DEBUG
        if FixtureDevices.isEnabled {
            store.replaceDevicesForPreview(FixtureDevices.catalog)
            Log.app.notice("fixtures enabled; polling disabled")
        } else {
            startLive(store: store, coordinator: coordinator)
        }
        #else
        startLive(store: store, coordinator: coordinator)
        #endif

        Task { await store.refreshVersion() }

        #if DEBUG
        if ProcessInfo.processInfo.environment["ADB2WIFI_SHOW_POPOVER"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.statusItemController?.showPopoverForDebug()
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.notice("terminate")
        store?.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(handleWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(handleDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc
    private func handleWillSleep(_ notification: Notification) {
        // No `adb` subprocesses while the Mac is asleep.
        Log.app.notice("system will sleep; pausing polling")
        store?.stop()
    }

    @objc
    private func handleDidWake(_ notification: Notification) {
        Log.app.notice("system woke; resuming polling")
        store?.start()
        guard let coordinator else { return }
        Task {
            // Give Wi-Fi a moment to come back after wake before retrying.
            try? await Task.sleep(for: .seconds(2))
            await coordinator.reconnectRememberedEndpoints()
        }
    }

    private func startLive(store: DeviceStore, coordinator: ConnectionCoordinator) {
        store.start()
        Task { await coordinator.reconnectRememberedEndpoints() }
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
