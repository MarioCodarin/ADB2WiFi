#if DEBUG
import ADB2WiFiCore
import AppKit
import SwiftUI

/// Debug-only PNG renderer used for visual QA and the README screenshot.
@MainActor
enum SnapshotRenderer {
    static func render(to path: String) {
        let settings = AppSettings()
        let store = DeviceStore(settings: settings, runner: ProcessCommandRunner())
        store.replaceDevicesForPreview(FixtureDevices.showcase)
        let coordinator = ConnectionCoordinator(store: store, clientProvider: { store.makeClient() })

        let root = PopoverRootView(
            settings: settings,
            store: store,
            model: PopoverModel(),
            coordinator: coordinator,
            onQuit: {},
            onChooseADB: {}
        )
        .frame(width: Theme.popoverWidth, height: 560)

        let light = root.environment(\.colorScheme, .light)
        let dark = root.environment(\.colorScheme, .dark)
        write(light, to: path)
        write(dark, to: path.replacingOccurrences(of: ".png", with: "-dark.png"))
    }

    private static func write(_ view: some View, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.isOpaque = false
        guard
            let image = renderer.nsImage,
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            Log.app.error("snapshot render failed")
            return
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            Log.app.notice("snapshot written path=\(path, privacy: .public)")
        } catch {
            Log.app.error("snapshot write failed error=\(String(describing: error), privacy: .private)")
        }
    }
}
#endif
