import ADB2WiFiCore
import SwiftUI

struct DeviceCardView: View {
    let device: Device
    var onConnect: () -> Void = {}
    var onRetry: () -> Void = {}
    var onContinue: (String) -> Void = { _ in }

    @State private var addressText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "iphone")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.model)
                        .font(.headline)
                    Text(device.identity.shortSerial)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
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
            }

            operationBody
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            if case .awaitingAddress(let suggested) = device.operation, addressText.isEmpty {
                addressText = suggested ?? ""
            }
        }
    }

    @ViewBuilder
    private var operationBody: some View {
        switch device.operation {
        case .idle:
            idleBody
        case .connecting(let step):
            connectingBody(current: step)
        case .awaitingAddress:
            addressPromptBody
        case .readyToUnplug:
            Label("Ready—unplug USB.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.semibold))
        case .failed(let error):
            VStack(alignment: .leading, spacing: 8) {
                Text(displayedGuidance(error))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var idleBody: some View {
        if device.usb?.state == .unauthorized {
            Text("Unauthorized")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if device.usb?.state == .offline {
            Text("Offline")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if device.isWiFiConnected {
            Label("Wi-Fi connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.semibold))
        } else if device.usb?.state == .device {
            Button("Connect via Wi-Fi", action: onConnect)
                .buttonStyle(.borderedProminent)
        }
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
            Button("Continue") {
                onContinue(addressText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func displayedGuidance(_ error: AppError) -> String {
        let guidance = error.guidance
        return guidance.isEmpty ? "Connection failed." : guidance
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

private extension ConnectionStep {
    var title: String {
        switch self {
        case .findingAddress: "Finding address"
        case .enablingWifi: "Enabling Wi-Fi"
        case .connecting: "Connecting"
        case .verifying: "Verifying"
        }
    }
}
