import ADB2WiFiCore
import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let store: DeviceStore
    private let coordinator: ConnectionCoordinator
    private let onQuit: () -> Void
    private var popover: NSPopover?

    init(
        settings: AppSettings,
        store: DeviceStore,
        coordinator: ConnectionCoordinator,
        onQuit: @escaping () -> Void
    ) {
        self.settings = settings
        self.store = store
        self.coordinator = coordinator
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        observeDevices()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = LogoMark.menuBarTemplate()
        button.imagePosition = .imageOnly
        button.toolTip = "ADB2WiFi"
        button.setAccessibilityLabel("ADB2WiFi")
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    /// The popover, and its SwiftUI view graph, is created on first use. Launching at login
    /// therefore costs only a status item, not a full SwiftUI hierarchy.
    private func makePopover() -> NSPopover {
        if let popover { return popover }
        let root = PopoverRootView(
            settings: settings,
            store: store,
            coordinator: coordinator,
            onQuit: onQuit,
            onChooseADB: { [weak self] in self?.chooseADB() }
        )
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]

        let popover = NSPopover()
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: Theme.popoverWidth, height: 420)
        popover.behavior = .transient
        popover.delegate = self
        if DebugFlags.lightAppearance {
            popover.appearance = NSAppearance(named: .aqua)
        }
        self.popover = popover
        return popover
    }

    func popoverWillShow(_ notification: Notification) {
        store.isPopoverOpen = true
    }

    func popoverDidClose(_ notification: Notification) {
        store.isPopoverOpen = false
    }

    private func chooseADB() {
        guard let popover else { return }
        PopoverOpenPanel.present(from: popover) { [weak self] url in
            guard let self, let url else { return }
            self.settings.adbPathOverride = url
            Task { await self.store.refreshVersion() }
        }
    }

    private func observeDevices() {
        withObservationTracking {
            _ = store.connectedCount
            _ = store.devices.count
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateStatusIcon()
                self?.observeDevices()
            }
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let connected = store.connectedCount
        button.image = LogoMark.menuBarTemplate(connected: connected > 0)
        if store.devices.isEmpty {
            button.toolTip = "ADB2WiFi — no phones"
        } else if connected > 0 {
            button.toolTip = "ADB2WiFi — \(connected) on Wi-Fi"
        } else {
            button.toolTip = "ADB2WiFi — \(store.devices.count) via USB"
        }
    }

    #if DEBUG
    /// Debug-only: show the popover without a physical click, for screenshots and UI QA.
    func showPopoverForDebug() {
        guard let button = statusItem.button else { return }
        let popover = makePopover()
        NSApp.activate()
        popover.behavior = .applicationDefined
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    #endif

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        let popover = makePopover()
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
