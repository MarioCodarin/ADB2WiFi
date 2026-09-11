import ADB2WiFiCore
import SwiftUI

struct SettingsPaneView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: DeviceStore
    var onChooseADB: () -> Void
    var onDone: () -> Void

    @FocusState private var focusedControl: SettingsFocus?

    private enum SettingsFocus: Hashable {
        case path, choose, done
    }

    private var resolvedURL: URL? {
        ADBExecutable.resolve(
            override: settings.adbPathOverride,
            fileManager: FileManager.default,
            pathEnv: ProcessInfo.processInfo.environment["PATH"] ?? "",
            environment: ProcessInfo.processInfo.environment
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
            Text("ADB executable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
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
                .focused($focusedControl, equals: .path)
                .accessibilityLabel("Path to adb")
                Button("Choose…", action: onChooseADB)
                    .accessibilityLabel("Choose…")
                    .focused($focusedControl, equals: .choose)
            }
            resolvedSection
            VStack(alignment: .leading, spacing: 4) {
                Text("Wi-Fi ADB requires a reachable shared network.")
                Text("Use it only on a trusted network.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text("ADB2WiFi · personal ADB utility")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Done")
                    .focused($focusedControl, equals: .done)
            }
        }
        .padding(14)
        .onAppear {
            Task { await store.refreshVersion() }
        }
        .onChange(of: settings.adbPathOverride) { _, _ in
            Task { await store.refreshVersion() }
        }
    }

    @ViewBuilder
    private var resolvedSection: some View {
        if let url = resolvedURL {
            Text(url.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let version = store.adbVersion {
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } else {
            Text("ADB not found")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
