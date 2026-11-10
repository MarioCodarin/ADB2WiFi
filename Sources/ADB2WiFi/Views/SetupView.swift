import ADB2WiFiCore
import SwiftUI

/// First-run and empty states. This is the only screen a new user sees, so it explains the
/// one prerequisite (ADB) without hiding the product behind documentation.
struct SetupView: View {
    var adbPath: URL?
    var adbVersion: String?
    var onChooseADB: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        Group {
            if adbPath == nil {
                missingADB
            } else {
                noDevices
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var missingADB: some View {
        VStack(spacing: 10) {
            mark(systemImage: "wrench.and.screwdriver", tint: Theme.warning)

            Text("Finish setup")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 2)

            Text("ADB2WiFi uses the adb already on your Mac. Nothing is bundled, downloaded, or uploaded.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onChooseADB) {
                Label("Choose adb…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)

            HStack(spacing: 8) {
                CopyButton(
                    text: "brew install --cask android-platform-tools",
                    label: "Copy install command",
                    systemImage: "terminal"
                )
                Button("Settings", action: onOpenSettings)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Text("Auto-detect checks Homebrew, Android Studio, and your PATH.")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .contain)
    }

    private var noDevices: some View {
        VStack(spacing: 12) {
            mark(systemImage: "iphone.gen3", tint: Theme.accent)

            VStack(spacing: 3) {
                Text("No phones yet")
                    .font(.system(size: 15, weight: .semibold))
                Text("Plug in a USB cable to get started.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                step(1, "Enable USB debugging in Developer options.")
                step(2, "Allow this Mac when your phone asks.")
                step(3, "Tap Connect over Wi-Fi.")
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.cardStroke)
            )

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.success)
                Text(adbVersion.map { "adb \($0) ready" } ?? "adb ready")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Link("USB debugging help", destination: URL(string: "https://developer.android.com/studio/debug/dev-options#enable")!)
                    .font(.system(size: 9))
            }
            .padding(.top, 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func mark(systemImage: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 48, height: 48)
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .frame(width: 16, height: 16)
                .background(Theme.accent.opacity(0.12), in: Circle())
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
