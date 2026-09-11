import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            LogoMark()
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
            Text("Plug in an Android device")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Unplug when the card says ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Enable USB debugging in Developer options, then accept the authorization prompt on the phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Wi-Fi ADB needs a reachable shared network. Use it only on a trusted network.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}
