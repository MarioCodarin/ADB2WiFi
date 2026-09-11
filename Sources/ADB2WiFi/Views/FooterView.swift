import SwiftUI

struct FooterView: View {
    var onSettings: () -> Void
    var onQuit: () -> Void

    @FocusState private var focusedControl: FooterFocus?

    private enum FooterFocus: Hashable {
        case settings, quit
    }

    var body: some View {
        HStack {
            Button("Settings", action: onSettings)
                .accessibilityLabel("Settings")
                .focused($focusedControl, equals: .settings)
            Spacer()
            Button("Quit", action: onQuit)
                .accessibilityLabel("Quit")
                .focused($focusedControl, equals: .quit)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
