import SwiftUI

struct HeaderView: View {
    let deviceCount: Int
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("ADB2WiFi")
                .font(.headline)
            Spacer()
            Text(deviceCount == 1 ? "1 device" : "\(deviceCount) devices")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
