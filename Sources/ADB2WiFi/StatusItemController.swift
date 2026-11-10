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
    private let popoverModel = PopoverModel(showingSettings: DebugFlags.showSettingsOnLaunch)
    private var readyTracker = ReadyTracker()
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
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// The popover, and its SwiftUI view graph, is created on first use. Launching at login
    /// therefore costs only a status item, not a full SwiftUI hierarchy.
    private func makePopover() -> NSPopover {
        if let popover { return popover }
        let root = PopoverRootView(
            settings: settings,
            store: store,
            model: popoverModel,
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
            _ = store.devices
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.checkReadyNotifications()
                self?.updateStatusIcon()
                self?.observeDevices()
            }
        }
    }

    private func checkReadyNotifications() {
        let newlyReady = readyTracker.newlyReady(in: store.devices)
        guard settings.notifyOnReady, !store.isPopoverOpen else { return }
        for device in newlyReady {
            ReadyNotifier.post(device: device)
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

    private func openPopover() {
        guard let button = statusItem.button else { return }
        let popover = makePopover()
        if popover.isShown { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()

        let open = menu.addItem(withTitle: "Open ADB2WiFi", action: #selector(menuOpen), keyEquivalent: "")
        open.target = self
        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(menuSettings), keyEquivalent: ",")
        settingsItem.target = self

        menu.addItem(.separator())
        let refresh = menu.addItem(withTitle: "Refresh Devices", action: #selector(menuRefresh), keyEquivalent: "r")
        refresh.target = self

        menu.addItem(.separator())
        let loginTitle = LaunchAtLogin.requiresApproval ? "Approve Launch at Login…" : "Launch at Login"
        let login = menu.addItem(withTitle: loginTitle, action: #selector(menuToggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = (LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval) ? .on : .off

        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit ADB2WiFi", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc
    private func menuOpen() {
        popoverModel.showingSettings = false
        openPopover()
    }

    @objc
    private func menuSettings() {
        popoverModel.showingSettings = true
        openPopover()
    }

    @objc
    private func menuRefresh() {
        Task { await store.refresh(userInitiated: true) }
    }

    @objc
    private func menuToggleLaunchAtLogin() {
        if LaunchAtLogin.requiresApproval {
            LaunchAtLogin.openSystemSettings()
            return
        }
        do {
            try LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
            if LaunchAtLogin.requiresApproval {
                LaunchAtLogin.openSystemSettings()
            }
        } catch {
            Log.settings.error("launch at login failed error=\(String(describing: error), privacy: .private)")
            NSSound.beep()
        }
    }

    @objc
    private func menuQuit() {
        onQuit()
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
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.type == .rightMouseDown {
            showContextMenu()
            return
        }

        let popover = makePopover()
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        popoverModel.showingSettings = false
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
