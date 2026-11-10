import ADB2WiFiCore
import SwiftUI

struct DeviceCardView: View {
    let device: Device
    var onConnect: () -> Void = {}
    var onRetry: () -> Void = {}
    var onContinue: (String) -> Void = { _ in }
    var onDisconnect: () -> Void = {}
    var onCancel: () -> Void = {}
    var onOpenShell: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedControl: CardFocus?
    @ViewState private var addressText = ""
    @ViewState private var isHovering = false

    private enum CardFocus: Hashable {
        case connect, retry, disconnect, continueButton, addressField
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            identityRow
            if let endpoint = device.network?.serial {
                endpointRow(endpoint)
            }
            statusBody
            actionBody
        }
        .padding(12)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(isHovering ? Theme.accent.opacity(0.35) : Theme.cardStroke)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: device.operation)
        .onHover { hovering in isHovering = hovering }
        .focusSection()
        .onChange(of: device.operation, initial: true) { _, operation in
            if case .awaitingAddress(let suggested) = operation, addressText.isEmpty {
                addressText = suggested ?? ""
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Identity

    private var identityRow: some View {
        HStack(alignment: .top, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.iconFill)
                    .frame(width: 30, height: 30)
                Image(systemName: "iphone")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.model.isEmpty ? "Android phone" : device.model)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(device.identity.shortSerial)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .accessibilityLabel("Serial \(device.identity.shortSerial)")
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if device.usb != nil {
                    CapsuleBadge(
                        text: "USB",
                        systemImage: "cable.connector",
                        tint: device.usb?.state == .device ? Theme.accent : Theme.warning
                    )
                }
                if device.network != nil {
                    CapsuleBadge(
                        text: "Wi-Fi",
                        systemImage: "wifi",
                        tint: device.isWiFiConnected ? Theme.success : .secondary,
                        emphasized: device.isWiFiConnected
                    )
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func endpointRow(_ endpoint: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.success)
            Text(endpoint)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 4)
            CopyButton(text: endpoint, label: "Copy")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Wi-Fi endpoint \(endpoint)")
    }

    // MARK: Status

    @ViewBuilder
    private var statusBody: some View {
        switch device.operation {
        case .idle:
            idleStatus
        case .connecting(let step):
            connectingBody(current: step)
        case .awaitingAddress:
            StatusLine(
                systemImage: "questionmark.circle.fill",
                tint: Theme.warning,
                title: "Choose an address",
                detail: "More than one Wi-Fi address was found. Pick the one on your network."
            )
        case .readyToUnplug:
            StatusLine(
                systemImage: "checkmark.circle.fill",
                tint: Theme.success,
                title: "You’re on Wi-Fi",
                detail: "Unplug USB to finish. The connection stays up."
            )
        case .failed(let error):
            StatusLine(
                systemImage: "exclamationmark.triangle.fill",
                tint: Theme.warning,
                title: error.title,
                detail: error.displayedGuidance
            )
        }
    }

    @ViewBuilder
    private var idleStatus: some View {
        if device.usb?.state == .unauthorized {
            StatusLine(
                systemImage: "lock.shield.fill",
                tint: Theme.warning,
                title: "Allow USB debugging",
                detail: AppError.authorizationPending.displayedGuidance
            )
        } else if device.usb?.state == .offline {
            StatusLine(
                systemImage: "bolt.horizontal.circle.fill",
                tint: Theme.warning,
                title: "Phone offline",
                detail: AppError.deviceOffline.displayedGuidance
            )
        } else if device.isWiFiConnected {
            StatusLine(
                systemImage: "checkmark.circle.fill",
                tint: Theme.success,
                title: "Wi-Fi connected",
                detail: "This Mac can run adb over Wi-Fi."
            )
        }
    }

    private func connectingBody(current: ConnectionStep) -> some View {
        let steps: [ConnectionStep] = [.findingAddress, .enablingWifi, .connecting, .verifying]
        let index = steps.firstIndex(of: current) ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text(current.title)
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 4)
                Text("\(index + 1)/\(steps.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            ProgressView(value: Double(index + 1), total: Double(steps.count))
                .progressViewStyle(.linear)
                .tint(Theme.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting, \(current.title), step \(index + 1) of \(steps.count)")
    }

    // MARK: Actions

    @ViewBuilder
    private var actionBody: some View {
        switch device.operation {
        case .idle:
            idleActions
        case .connecting:
            EmptyView()
        case .awaitingAddress:
            addressPrompt
        case .readyToUnplug:
            connectedActions
        case .failed:
            retryActions
        }
    }

    @ViewBuilder
    private var idleActions: some View {
        if device.usb?.state == .unauthorized || device.usb?.state == .offline {
            retryOnlyAction
        } else if device.isWiFiConnected {
            connectedActions
        } else if device.usb?.state == .device {
            Button(action: onConnect) {
                Label("Connect over Wi-Fi", systemImage: "wifi")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .focused($focusedControl, equals: .connect)
            .accessibilityHint("Enables Wi-Fi ADB, connects, and verifies this phone.")
        }
    }

    private var connectedActions: some View {
        HStack(spacing: 8) {
            if let endpoint = device.network?.serial {
                CopyButton(
                    text: Endpoint.connectCommand(endpoint),
                    label: "Copy adb command",
                    systemImage: "doc.on.doc"
                )
                Button(action: onOpenShell) {
                    Label("Shell", systemImage: "terminal")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open Terminal attached to this phone.")
                .accessibilityHint("Opens a Terminal window with an adb shell for this phone.")
            }
            Spacer(minLength: 4)
            Button("Disconnect", action: onDisconnect)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .help(ConnectionCoordinator.disconnectHelpText)
                .accessibilityHint(ConnectionCoordinator.disconnectHelpText)
                .focused($focusedControl, equals: .disconnect)
        }
    }

    private var retryOnlyAction: some View {
        Button("Try again", action: onRetry)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .focused($focusedControl, equals: .retry)
    }

    private var retryActions: some View {
        HStack(spacing: 8) {
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .focused($focusedControl, equals: .retry)
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var addressPrompt: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField("192.0.2.20", text: $addressText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .focused($focusedControl, equals: .addressField)
                .accessibilityLabel("IPv4 address")
            HStack {
                Button("Continue") {
                    onContinue(addressText)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .focused($focusedControl, equals: .continueButton)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
