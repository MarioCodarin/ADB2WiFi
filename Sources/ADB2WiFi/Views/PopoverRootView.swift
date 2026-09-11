import AppKit
import ADB2WiFiCore
import SwiftUI

struct PopoverRootView: View {
    var settings: AppSettings
    @State private var devices: [Device] = FixtureDevices.catalog
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsPaneView(settings: settings) {
                    showingSettings = false
                }
            } else {
                deviceList
            }
        }
        .frame(width: 360)
        .frame(minHeight: 220, maxHeight: 560)
        .background(.regularMaterial)
        .tint(Theme.accent)
    }

    private var deviceList: some View {
        VStack(spacing: 0) {
            HeaderView(deviceCount: devices.count, onRefresh: {})
            Divider()
            if devices.isEmpty {
                EmptyStateView()
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(devices) { device in
                            DeviceCardView(device: device)
                        }
                    }
                    .padding(10)
                }
            }
            Divider()
            FooterView(
                onSettings: { showingSettings = true },
                onQuit: { NSApp.terminate(nil) }
            )
        }
    }
}
