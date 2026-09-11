import AppKit
import ADB2WiFiCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings?
    private var store: DeviceStore?
    private var coordinator: ConnectionCoordinator?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = AppSettings()
        let runner = ProcessCommandRunner()
        let store = DeviceStore(settings: settings, runner: runner)
        let coordinator = ConnectionCoordinator(store: store, clientProvider: { store.makeClient() })

        self.settings = settings
        self.store = store
        self.coordinator = coordinator

        statusItemController = StatusItemController(
            settings: settings,
            store: store,
            coordinator: coordinator,
            onQuit: { [weak self] in
                self?.quit()
            }
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func handleDidWake(_ notification: Notification) {
        Task { await store?.refresh() }
    }

    private func quit() {
        store?.stop()
        NSApp.terminate(nil)
    }
}
