import ADB2WiFiCore
import SwiftUI

struct PopoverRootView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: DeviceStore
    var coordinator: ConnectionCoordinator
    var onQuit: () -> Void
    var onChooseADB: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var showingSettings = DebugFlags.showSettingsOnLaunch

    var body: some View {
        Group {
            if showingSettings {
                SettingsPaneView(settings: settings, store: store, onChooseADB: onChooseADB) {
                    showingSettings = false
                    Task { await store.refresh(userInitiated: true) }
                }
            } else {
                deviceList
            }
        }
        .frame(width: Theme.popoverWidth)
        .frame(minHeight: 200, maxHeight: 560)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                LinearGradient(
                    colors: [Theme.accent.opacity(0.07), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
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
            HeaderView(
                deviceCount: store.devices.count,
                connectedCount: store.connectedCount,
                isRefreshing: store.isRefreshing,
                onRefresh: { Task { await store.refresh(userInitiated: true) } }
            )
            Divider().overlay(Theme.hairline)

            if let error = store.globalError,
               !(store.devices.isEmpty && error.needsADBSetup) {
                errorBanner(error)
                Divider().overlay(Theme.hairline)
            }

            content

            Divider().overlay(Theme.hairline)
            FooterView(
                onSettings: { showSettings() },
                onQuit: onQuit
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.hasLoaded && store.devices.isEmpty {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Looking for your phone…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if store.devices.isEmpty, store.globalError?.needsADBSetup == true {
            SetupView(
                adbPath: nil,
                adbVersion: nil,
                onChooseADB: onChooseADB,
                onOpenSettings: { showSettings() }
            )
        } else if store.devices.isEmpty {
            SetupView(
                adbPath: store.adbPath,
                adbVersion: store.adbVersion,
                onChooseADB: onChooseADB,
                onOpenSettings: { showSettings() }
            )
        } else if store.devices.count > 3 {
            // Only very busy setups scroll; the common one-to-three-phone case renders
            // as a single, fully visible stack.
            ScrollView {
                cards
            }
        } else {
            cards
        }
    }

    private var cards: some View {
        VStack(spacing: 8) {
            ForEach(store.devices) { device in
                DeviceCardView(
                    device: device,
                    onConnect: { connect(device) },
                    onRetry: { retry(device) },
                    onContinue: { address in continueConnect(device, address: address) },
                    onDisconnect: { disconnect(device) },
                    onCancel: { coordinator.cancel(identity: device.identity) }
                )
            }
        }
        .padding(10)
    }

    private func errorBanner(_ error: AppError) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.warning)
            Text(error.displayedGuidance)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Retry") {
                Task { await store.refresh(userInitiated: true) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func showSettings() {
        if reduceMotion {
            showingSettings = true
        } else {
            withAnimation(.easeInOut(duration: 0.18)) { showingSettings = true }
        }
    }

    private func connect(_ device: Device) {
        Task { await coordinator.connect(identity: device.identity) }
    }

    private func retry(_ device: Device) {
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
        Task { await coordinator.connect(identity: device.identity, manualAddress: address) }
    }

    private func disconnect(_ device: Device) {
        Task { await coordinator.disconnect(identity: device.identity) }
    }
}
