import SwiftUI

struct HeaderView: View {
    let deviceCount: Int
    var onRefresh: () -> Void

    @FocusState private var refreshFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            LogoMark()
                .foregroundStyle(Theme.accent)
                .frame(width: 16, height: 16)
            Text("ADB2WiFi")
                .font(.headline)
            Spacer()
            Text(deviceCount == 1 ? "1 device" : "\(deviceCount) devices")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .help("Refresh")
            .accessibilityLabel("Refresh")
            .accessibilityIdentifier("Refresh")
            .focused($refreshFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
