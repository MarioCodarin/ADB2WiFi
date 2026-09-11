import AppKit
import ADB2WiFiCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let settings: AppSettings
    private let store: DeviceStore

    init(
        settings: AppSettings,
        store: DeviceStore,
        coordinator: ConnectionCoordinator,
        onQuit: @escaping () -> Void
    ) {
        self.settings = settings
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()
        configureStatusItem()
        configurePopover(settings: settings, store: store, coordinator: coordinator, onQuit: onQuit)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "ADB2WiFi")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "ADB2WiFi"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover(
        settings: AppSettings,
        store: DeviceStore,
        coordinator: ConnectionCoordinator,
        onQuit: @escaping () -> Void
    ) {
        let root = PopoverRootView(
            settings: settings,
            store: store,
            coordinator: coordinator,
            onQuit: onQuit,
            onChooseADB: { [weak self] in
                self?.chooseADB()
            }
        )
        .frame(width: 360)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.delegate = self
    }

    func popoverWillShow(_ notification: Notification) {
        store.isPopoverOpen = true
    }

    func popoverDidClose(_ notification: Notification) {
        store.isPopoverOpen = false
    }

    private func chooseADB() {
        PopoverOpenPanel.present(from: popover) { [weak self] url in
            if let url {
                self?.settings.adbPathOverride = url
            }
        }
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
