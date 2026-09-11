import AppKit
import SwiftUI

/// Phone silhouette with a Wi-Fi chevron lifting off the top-right.
struct LogoMark: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            let line = max(1.1, size.width * 0.085)
            let phone = LogoMarkGeometry.phoneRect(in: bounds)
            let phonePath = Path(roundedRect: phone, cornerSize: CGSize(width: phone.width * 0.22, height: phone.width * 0.22))
            context.stroke(
                phonePath,
                with: .foreground,
                style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            )

            let slitWidth = phone.width * 0.28
            let slitHeight = max(1, line * 0.45)
            let slit = CGRect(
                x: phone.midX - slitWidth / 2,
                y: phone.minY + phone.height * 0.11,
                width: slitWidth,
                height: slitHeight
            )
            context.fill(Path(roundedRect: slit, cornerRadius: slitHeight / 2), with: .foreground)

            let origin = CGPoint(x: phone.maxX - phone.width * 0.02, y: phone.minY + phone.height * 0.16)
            for radius in [size.width * 0.13, size.width * 0.22, size.width * 0.31] {
                context.stroke(
                    LogoMarkGeometry.chevron(center: origin, radius: radius),
                    with: .foreground,
                    style: StrokeStyle(lineWidth: line * 0.85, lineCap: .round)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @MainActor
    static func menuBarTemplate() -> NSImage {
        let point = CGSize(width: 18, height: 18)
        let renderer = ImageRenderer(content:
            LogoMark()
                .foregroundStyle(.black)
                .frame(width: point.width, height: point.height)
        )
        renderer.scale = 2
        renderer.isOpaque = false
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: point.width, height: point.height))
        image.isTemplate = true
        image.size = NSSize(width: point.width, height: point.height)
        return image
    }
}

private enum LogoMarkGeometry {
    static func phoneRect(in rect: CGRect) -> CGRect {
        let phoneWidth = rect.width * 0.40
        let phoneHeight = rect.height * 0.62
        return CGRect(
            x: rect.midX - phoneWidth * 0.68,
            y: rect.midY - phoneHeight * 0.40,
            width: phoneWidth,
            height: phoneHeight
        )
    }

    static func chevron(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-110),
            endAngle: .degrees(-20),
            clockwise: false
        )
        return path
    }
}
