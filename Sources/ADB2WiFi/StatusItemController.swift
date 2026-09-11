import AppKit
import ADB2WiFiCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let settings: AppSettings

    override init() {
        settings = AppSettings()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()
        configureStatusItem()
        configurePopover()
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

    private func configurePopover() {
        let root = PopoverRootView(settings: settings)
            .frame(width: 360)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
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
    }
}
