import SwiftUI

struct FooterView: View {
    var onSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityLabel("Settings")

            Spacer(minLength: 4)

            Text("v\(AppInfo.version)")
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Version \(AppInfo.version)")

            Spacer(minLength: 4)

            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
            }
            .accessibilityLabel("Quit ADB2WiFi")
        }
        .font(.system(size: 10, weight: .medium))
        .labelStyle(.titleAndIcon)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
