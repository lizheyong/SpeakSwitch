import AppKit
import SwiftUI

/// A microphone whose cradle turns into a switching arrow.
/// Coordinates use a 1024-point canvas with a top-left origin.
/// Keep the two paths in scripts/make-icon.swift aligned with this geometry.
enum BrandMarkGeometry {
    static let reference: CGFloat = 1024
    static let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    static let tileRadius: CGFloat = 186
    static let stroke: CGFloat = 52
    static let ink = CGRect(x: 296, y: 248, width: 488, height: 568)

    static var microphone: CGPath {
        CGPath(roundedRect: CGRect(x: 446, y: 248, width: 132, height: 314),
               cornerWidth: 66, cornerHeight: 66, transform: nil)
    }

    static var switchingCradle: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 322, y: 472))
        path.addLine(to: CGPoint(x: 322, y: 522))
        path.addCurve(to: CGPoint(x: 512, y: 714),
                      control1: CGPoint(x: 322, y: 628), control2: CGPoint(x: 406, y: 714))
        path.addCurve(to: CGPoint(x: 702, y: 522),
                      control1: CGPoint(x: 618, y: 714), control2: CGPoint(x: 702, y: 628))
        path.addLine(to: CGPoint(x: 702, y: 400))
        path.move(to: CGPoint(x: 646, y: 456))
        path.addLine(to: CGPoint(x: 702, y: 400))
        path.addLine(to: CGPoint(x: 758, y: 456))
        path.move(to: CGPoint(x: 512, y: 714))
        path.addLine(to: CGPoint(x: 512, y: 790))
        path.move(to: CGPoint(x: 442, y: 790))
        path.addLine(to: CGPoint(x: 582, y: 790))
        return path
    }

    static func drawSymbol(in context: CGContext, color: CGColor) {
        context.setFillColor(color)
        context.addPath(microphone)
        context.fillPath()
        context.setStrokeColor(color)
        context.setLineWidth(stroke)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(switchingCradle)
        context.strokePath()
    }
}

/// The application mark uses the same silhouette as the menu bar template.
struct BrandMark: View {
    var size: CGFloat = 26

    var body: some View {
        Canvas { canvas, dimensions in
            canvas.withCGContext { context in
                let scale = min(dimensions.width, dimensions.height) / BrandMarkGeometry.reference
                context.scaleBy(x: scale, y: scale)
                let tile = CGPath(roundedRect: BrandMarkGeometry.tile,
                                  cornerWidth: BrandMarkGeometry.tileRadius,
                                  cornerHeight: BrandMarkGeometry.tileRadius, transform: nil)
                context.setFillColor(NSColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1).cgColor)
                context.addPath(tile)
                context.fillPath()
                context.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
                context.setLineWidth(6)
                context.addPath(tile)
                context.strokePath()
                context.translateBy(x: 512 - BrandMarkGeometry.ink.midX, y: 512 - BrandMarkGeometry.ink.midY)
                BrandMarkGeometry.drawSymbol(in: context, color: NSColor(red: 0.17, green: 0.20, blue: 0.24, alpha: 1).cgColor)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A template image lets macOS provide menu bar contrast and selection colors.
@MainActor
enum BrandStatusIcon {
    static let image: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let ink = BrandMarkGeometry.ink
            let scale = 16 / max(ink.width, ink.height)
            context.saveGState()
            context.translateBy(x: side / 2, y: side / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -ink.midX, y: -ink.midY)
            BrandMarkGeometry.drawSymbol(in: context, color: NSColor.black.cgColor)
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
