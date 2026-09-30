import SwiftUI

struct HeaderView: View {
    let deviceCount: Int
    var isRefreshing: Bool = false
    var onRefresh: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var refreshFocused: Bool
    @ViewState private var rotationDegrees = 0.0

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
            Button(action: refreshTapped) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(rotationDegrees))
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .help("Refresh")
            .accessibilityLabel("Refresh")
            .accessibilityIdentifier("Refresh")
            .accessibilityValue(isRefreshing ? "Refreshing" : "")
            .focused($refreshFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func refreshTapped() {
        if !reduceMotion {
            withAnimation(.linear(duration: 0.6)) {
                rotationDegrees += 360
            }
        }
        onRefresh()
    }
}
