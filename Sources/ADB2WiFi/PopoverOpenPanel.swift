import AppKit

/// Presents `NSOpenPanel` without letting a transient popover dismiss underneath it.
@MainActor
enum PopoverOpenPanel {
    static func present(from popover: NSPopover, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        let previousBehavior = popover.behavior
        popover.behavior = .applicationDefined

        let finish: @MainActor (NSApplication.ModalResponse) -> Void = { response in
            popover.behavior = previousBehavior
            completion(response == .OK ? panel.url : nil)
        }

        if let window = popover.contentViewController?.view.window {
            panel.beginSheetModal(for: window) { response in
                Task { @MainActor in
                    finish(response)
                }
            }
        } else {
            finish(panel.runModal())
        }
    }
}
