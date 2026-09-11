import ADB2WiFiCore
import SwiftUI

struct PopoverRootView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: DeviceStore
    var coordinator: ConnectionCoordinator
    var onQuit: () -> Void
    var onChooseADB: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false

    private var usingFixtures: Bool { FixtureDevices.isEnabled }

    private var devices: [Device] {
        usingFixtures ? FixtureDevices.catalog : store.devices
    }

    var body: some View {
        Group {
            if showingSettings {
                SettingsPaneView(settings: settings, store: store, onChooseADB: onChooseADB) {
                    showingSettings = false
                    Task { await store.refresh() }
                }
                .transition(reduceMotion ? .identity : .opacity)
            } else {
                deviceList
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showingSettings)
        .frame(width: 360)
        .frame(minHeight: 220, maxHeight: 560)
        .background(.regularMaterial)
        .tint(Theme.accent)
        .transaction { transaction in
            if reduceMotion {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
    }

    private var deviceList: some View {
        VStack(spacing: 0) {
            HeaderView(deviceCount: devices.count, onRefresh: {
                Task { await store.refresh() }
            })
            Divider()
            if let error = store.globalError, !usingFixtures {
                Text(error.guidance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                Divider()
            }
            if devices.isEmpty {
                if usingFixtures || store.globalError == nil {
                    EmptyStateView()
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(devices) { device in
                            DeviceCardView(
                                device: device,
                                onConnect: { connect(device) },
                                onRetry: { retry(device) },
                                onContinue: { address in continueConnect(device, address: address) },
                                onDisconnect: { disconnect(device) }
                            )
                        }
                    }
                    .padding(10)
                }
            }
            Divider()
            FooterView(
                onSettings: { showingSettings = true },
                onQuit: onQuit
            )
        }
    }

    private func connect(_ device: Device) {
        guard !usingFixtures else { return }
        Task { await coordinator.connect(identity: device.identity) }
    }

    private func retry(_ device: Device) {
        guard !usingFixtures else { return }
        Task {
            if device.usb?.state == .unauthorized || device.usb?.state == .offline {
                await store.refresh()
                await coordinator.connect(identity: device.identity)
                return
            }
            await coordinator.retry(identity: device.identity)
        }
    }

    private func continueConnect(_ device: Device, address: String) {
        guard !usingFixtures else { return }
        Task { await coordinator.connect(identity: device.identity, manualAddress: address) }
    }

    private func disconnect(_ device: Device) {
        guard !usingFixtures else { return }
        Task { await coordinator.disconnect(identity: device.identity) }
    }
}
