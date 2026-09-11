import ADB2WiFiCore
import SwiftUI

struct SettingsPaneView: View {
    @Bindable var settings: AppSettings
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
            Text("ADB executable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(
                "Path to adb",
                text: Binding(
                    get: { settings.adbPathOverride?.path ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        settings.adbPathOverride = trimmed.isEmpty ? nil : URL(fileURLWithPath: trimmed)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            Spacer()
            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
    }
}
