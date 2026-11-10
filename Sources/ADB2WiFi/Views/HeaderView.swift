import SwiftUI

struct HeaderView: View {
    let deviceCount: Int
    var connectedCount: Int = 0
    var isRefreshing: Bool = false
    var onRefresh: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var rotation = 0.0

    private var subtitle: String {
        if deviceCount == 0 { return "Waiting for a phone" }
        let devices = deviceCount == 1 ? "1 phone" : "\(deviceCount) phones"
        guard connectedCount > 0 else { return devices }
        return "\(devices) · \(connectedCount) on Wi-Fi"
    }

    var body: some View {
        HStack(spacing: 10) {
            LogoMark(connected: connectedCount > 0)
                .foregroundStyle(Theme.accent)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("ADB2WiFi")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(rotation))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isRefreshing ? Theme.accent : .secondary)
            .help("Refresh devices")
            .accessibilityLabel("Refresh devices")
            .accessibilityIdentifier("Refresh")
            .accessibilityValue(isRefreshing ? "Refreshing" : "")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func refresh() {
        if !reduceMotion {
            withAnimation(.linear(duration: 0.5)) { rotation += 360 }
        }
        onRefresh()
    }
}
