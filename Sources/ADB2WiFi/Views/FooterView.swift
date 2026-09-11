import SwiftUI

struct FooterView: View {
    var onSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        HStack {
            Button("Settings", action: onSettings)
            Spacer()
            Button("Quit", action: onQuit)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
