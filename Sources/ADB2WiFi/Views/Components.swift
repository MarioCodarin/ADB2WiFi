import AppKit
import SwiftUI

/// Small, quiet capsule used for transport and state labels.
struct CapsuleBadge: View {
    let text: String
    var systemImage: String?
    var tint: Color = .secondary
    var emphasized: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .foregroundStyle(emphasized ? Color.white : tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            emphasized ? tint : tint.opacity(0.12),
            in: Capsule()
        )
    }
}

/// Icon + title + optional detail. Used for success, warning, and failure states.
struct StatusLine: View {
    let systemImage: String
    let tint: Color
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Copies a string and briefly confirms it in place.
struct CopyButton: View {
    let text: String
    var label: String = "Copy"
    var systemImage: String = "doc.on.doc"

    @ViewState private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(.easeOut(duration: 0.15)) { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.15)) { copied = false }
            }
        } label: {
            Label(copied ? "Copied" : label, systemImage: copied ? "checkmark" : systemImage)
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(copied ? "Copied" : label)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(.tertiary)
    }
}
