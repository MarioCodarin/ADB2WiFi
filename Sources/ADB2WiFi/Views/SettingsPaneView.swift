import ADB2WiFiCore
import SwiftUI

struct SettingsPaneView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: DeviceStore
    var onChooseADB: () -> Void
    var onDone: () -> Void

    @ViewState private var launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval
    @ViewState private var launchAtLoginError: String?

    private var resolvedADB: URL? { store.resolvedExecutable() }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.hairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    adbSection
                    connectionSection
                    generalSection
                    diagnosticsSection
                }
                .padding(14)
            }
            Divider().overlay(Theme.hairline)
            footer
        }
        .frame(maxHeight: 560)
        .task(id: settings.adbPathOverride) {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            await store.refreshVersion()
        }
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Done")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var adbSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Android Platform Tools")

            HStack(spacing: 6) {
                TextField(
                    "Path to adb",
                    text: Binding(
                        get: { settings.adbPathOverride?.path ?? "" },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            let expanded = (trimmed as NSString).expandingTildeInPath
                            settings.adbPathOverride = expanded.isEmpty ? nil : URL(fileURLWithPath: expanded)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, design: .monospaced))
                .accessibilityLabel("Path to adb")

                Button("Choose…", action: onChooseADB)
                    .controlSize(.small)
                    .accessibilityLabel("Choose adb executable")
            }

            HStack(spacing: 8) {
                Button("Auto-detect", action: settings.resetADBPath)
                    .controlSize(.small)
                    .disabled(settings.adbPathOverride == nil)
                    .accessibilityLabel("Auto-detect adb")
                if resolvedADB == nil {
                    CopyButton(
                        text: "brew install --cask android-platform-tools",
                        label: "Copy install command",
                        systemImage: "terminal"
                    )
                }
            }

            resolvedStatus
        }
    }

    @ViewBuilder
    private var resolvedStatus: some View {
        if let resolvedADB {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.success)
                    Text(store.adbVersion.map { "adb \($0)" } ?? "adb found")
                        .font(.system(size: 10, weight: .medium))
                }
                Text(resolvedADB.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(resolvedADB.path)
                if let override = settings.adbPathOverride, override.path != resolvedADB.path {
                    Text("Override not found — using the auto-detected adb.")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.warning)
                }
            }
        } else {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.warning)
                Text("No adb found. Install Platform Tools or choose a path.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Connection")
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("ADB port")
                        .font(.system(size: 11, weight: .medium))
                    Text("Used by tcpip and connect. Default 5555.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                TextField("5555", value: $settings.port, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 62)
                    .accessibilityLabel("ADB port")
            }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "General")
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    do {
                        try LaunchAtLogin.set(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval
                        launchAtLoginError = nil
                    } catch {
                        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval
                        launchAtLoginError = error.localizedDescription
                    }
                }
            ))
            .font(.system(size: 11))
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityHint("Opens ADB2WiFi automatically when you log in.")

            if let launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if LaunchAtLogin.requiresApproval {
                HStack(spacing: 6) {
                    Text("Approve in System Settings › General › Login Items.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Open") { LaunchAtLogin.openSystemSettings() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }

            Toggle("Reconnect remembered phones", isOn: $settings.autoReconnect)
                .font(.system(size: 11))
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityHint("Tries the last verified Wi-Fi endpoint when ADB2WiFi launches or wakes.")

            if settings.rememberedEndpoints.isEmpty {
                Text("No remembered endpoints yet. Connect a phone over Wi-Fi once.")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 6) {
                    Text("\(settings.rememberedEndpoints.count) remembered endpoint\(settings.rememberedEndpoints.count == 1 ? "" : "s")")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Clear") { settings.clearRememberedEndpoints() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .accessibilityLabel("Clear remembered endpoints")
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Diagnostics")
            CopyButton(
                text: diagnostics,
                label: "Copy diagnostics",
                systemImage: "stethoscope"
            )
            Text("No account, telemetry, or keys. Nothing leaves this Mac.")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("ADB2WiFi \(AppInfo.version)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            Link("GitHub", destination: AppInfo.repository)
                .font(.system(size: 9))
            Text("·")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Link("MIT License", destination: AppInfo.repository.appendingPathComponent("blob/main/LICENSE"))
                .font(.system(size: 9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var diagnostics: String {
        Diagnostics.summary(
            appVersion: AppInfo.version,
            adbPath: resolvedADB,
            adbVersion: store.adbVersion,
            deviceCount: store.devices.count,
            connectedCount: store.connectedCount,
            lastError: store.globalError
        )
    }
}
