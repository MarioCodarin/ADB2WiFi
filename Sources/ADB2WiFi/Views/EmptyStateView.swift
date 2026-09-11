import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cable.connector")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Plug in an Android device")
                .font(.headline)
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
    }
}
