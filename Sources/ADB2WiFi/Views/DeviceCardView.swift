import ADB2WiFiCore
import SwiftUI

struct DeviceCardView: View {
    let device: Device
    var onConnect: () -> Void = {}
    var onRetry: () -> Void = {}
    var onContinue: (String) -> Void = { _ in }
    var onDisconnect: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedControl: CardFocus?
    @State private var addressText = ""

    private enum CardFocus: Hashable {
        case connect, retry, disconnect, continueButton, addressField
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                identityRow
                statusBody
                    .id(operationAnimationID)
                    .transition(reduceMotion ? .identity : .opacity)
            }
            // Combine identity + status; keep buttons/fields as separate AX elements.
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(device.model), serial \(device.identity.shortSerial)")
            .accessibilityValue(device.accessibilityValue)

            actionBody
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: operationAnimationID)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .focusSection()
        .onAppear {
            if case .awaitingAddress(let suggested) = device.operation, addressText.isEmpty {
                addressText = suggested ?? ""
            }
        }
    }

    private var identityRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.model)
                    .font(.headline)
                Text(device.identity.shortSerial)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let endpoint = device.network?.serial {
                    Text(endpoint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                if device.usb != nil {
                    Badge(text: "USB", emphasized: device.usb?.state == .device)
                }
                if device.network != nil {
                    Badge(text: "Wi-Fi", emphasized: device.isWiFiConnected)
                }
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var statusBody: some View {
        switch device.operation {
        case .idle:
            idleStatus
        case .connecting(let step):
            connectingBody(current: step)
        case .awaitingAddress:
            EmptyView()
        case .readyToUnplug:
            Label("Ready—unplug USB.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.semibold))
        case .failed(let error):
            Text(error.displayedGuidance)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var idleStatus: some View {
        if device.usb?.state == .unauthorized {
            guidanceText(.authorizationPending)
        } else if device.usb?.state == .offline {
            guidanceText(.deviceOffline)
        } else if device.isWiFiConnected {
            Label("Wi-Fi connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var actionBody: some View {
        switch device.operation {
        case .idle:
            idleActions
        case .connecting:
            EmptyView()
        case .awaitingAddress:
            addressPromptBody
        case .readyToUnplug:
            disconnectButton
        case .failed:
            retryButton
        }
    }

    @ViewBuilder
    private var idleActions: some View {
        if device.usb?.state == .unauthorized || device.usb?.state == .offline {
            retryButton
        } else if device.isWiFiConnected {
            disconnectButton
        } else if device.usb?.state == .device {
            Button("Connect via Wi-Fi", action: onConnect)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Connect via Wi-Fi")
                .focused($focusedControl, equals: .connect)
        }
    }

    private var disconnectButton: some View {
        Button("Disconnect", action: onDisconnect)
            .buttonStyle(.bordered)
            .help(ConnectionCoordinator.disconnectHelpText)
            .accessibilityLabel("Disconnect")
            .accessibilityHint(ConnectionCoordinator.disconnectHelpText)
            .focused($focusedControl, equals: .disconnect)
    }

    private var retryButton: some View {
        Button("Retry", action: onRetry)
            .buttonStyle(.bordered)
            .accessibilityLabel("Retry")
            .focused($focusedControl, equals: .retry)
    }

    private func guidanceText(_ error: AppError) -> some View {
        Text(error.displayedGuidance)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func connectingBody(current: ConnectionStep) -> some View {
        let steps: [ConnectionStep] = [.findingAddress, .enablingWifi, .connecting, .verifying]
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(steps, id: \.self) { step in
                let isCurrent = step == current
                let isDone = steps.firstIndex(of: step)! < steps.firstIndex(of: current)!
                HStack(spacing: 8) {
                    if isCurrent {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isDone ? .green : .secondary)
                            .accessibilityHidden(true)
                    }
                    Text(step.title)
                        .font(.subheadline)
                        .foregroundStyle(isCurrent ? .primary : .secondary)
                }
            }
        }
    }

    private var addressPromptBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("IPv4 address", text: $addressText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedControl, equals: .addressField)
                .accessibilityLabel("IPv4 address")
            Button("Continue") {
                onContinue(addressText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Continue")
            .focused($focusedControl, equals: .continueButton)
        }
    }

    private var operationAnimationID: String {
        switch device.operation {
        case .idle: "idle"
        case .connecting(let step): "connecting-\(step.rawValue)"
        case .awaitingAddress: "awaitingAddress"
        case .readyToUnplug: "readyToUnplug"
        case .failed: "failed"
        }
    }

}

private struct Badge: View {
    let text: String
    var emphasized: Bool

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(emphasized ? Color.white : Color.secondary)
            .background(
                emphasized ? Theme.accent : Color.secondary.opacity(0.18),
                in: Capsule()
            )
    }
}


