import ADB2WiFiCore
import SwiftUI

/// Rows for phones that are remembered but not currently listed by `adb devices`.
struct RecentConnectionsView: View {
    let connections: [RememberedDevice]
    var showsEmptyHeader: Bool
    var onReconnect: (RememberedDevice) async -> Bool
    var onForget: (RememberedDevice) -> Void

    @ViewState private var connecting: Set<DeviceIdentity> = []
    @ViewState private var failures: Set<DeviceIdentity> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if showsEmptyHeader {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No phones connected")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Reconnect a phone you used before, or plug in USB.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)
            }

            SectionLabel(text: "Recently connected")

            ForEach(connections) { connection in
                row(connection)
            }
        }
        .padding(.horizontal, 2)
    }

    private func row(_ connection: RememberedDevice) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.iconFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(connection.model.isEmpty ? "Android phone" : connection.model)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(connection.endpoint)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                if connecting.contains(connection.identity) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 66)
                } else {
                    Button("Reconnect") { reconnect(connection) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityLabel("Reconnect \(connection.model)")
                    Button {
                        onForget(connection)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Forget this phone")
                    .accessibilityLabel("Forget \(connection.model)")
                }
            }

            HStack(spacing: 3) {
                Text("Last connected")
                Text(connection.lastConnected, style: .relative)
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)

            if failures.contains(connection.identity) {
                Text("Not reachable. Check that the phone is on Wi-Fi.")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.cardStroke)
        )
        .accessibilityElement(children: .contain)
    }

    private func reconnect(_ connection: RememberedDevice) {
        guard !connecting.contains(connection.identity) else { return }
        connecting.insert(connection.identity)
        failures.remove(connection.identity)
        Task { @MainActor in
            let connected = await onReconnect(connection)
            connecting.remove(connection.identity)
            if !connected {
                failures.insert(connection.identity)
            }
        }
    }
}
