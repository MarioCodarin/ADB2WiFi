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
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(16)
    }
}
