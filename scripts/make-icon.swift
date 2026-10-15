import AppKit

// Coordinates match BrandMarkGeometry in Sources/VoiceSwitch/BrandMark.swift.
// The microphone's cradle ends in a switching arrow; no lettering is used.
let reference: CGFloat = 1024
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileRadius: CGFloat = 186
let stroke: CGFloat = 52
let ink = CGRect(x: 296, y: 248, width: 488, height: 568)
let graphite = NSColor(red: 0.17, green: 0.20, blue: 0.24, alpha: 1).cgColor

func microphonePath() -> CGPath {
    CGPath(roundedRect: CGRect(x: 446, y: 248, width: 132, height: 314),
           cornerWidth: 66, cornerHeight: 66, transform: nil)
}

func switchingCradlePath() -> CGPath {
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

func drawSymbol(in context: CGContext, color: CGColor) {
    context.setFillColor(color)
    context.addPath(microphonePath())
    context.fillPath()
    context.setStrokeColor(color)
    context.setLineWidth(stroke)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(switchingCradlePath())
    context.strokePath()
}

func drawAppIcon(in context: CGContext) {
    let plate = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 10), blur: 22,
                      color: NSColor.black.withAlphaComponent(0.16).cgColor)
    context.setFillColor(NSColor.white.cgColor)
    context.addPath(plate)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(plate)
    context.clip()
    let colors = [
        NSColor(red: 0.995, green: 0.997, blue: 1, alpha: 1).cgColor,
        NSColor(red: 0.90, green: 0.92, blue: 0.94, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    context.restoreGState()
    context.addPath(plate)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
    context.setLineWidth(5)
    context.strokePath()

    context.translateBy(x: 512 - ink.midX, y: 512 - ink.midY)
    drawSymbol(in: context, color: graphite)
}

func png(pixels: Int, template: Bool = false, dark: Bool = false) -> Data {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: 1, y: -1)
    if template {
        let scale = CGFloat(pixels) * (16 / 18) / max(ink.width, ink.height)
        context.translateBy(x: CGFloat(pixels) / 2, y: CGFloat(pixels) / 2)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -ink.midX, y: -ink.midY)
        drawSymbol(in: context, color: dark ? NSColor.white.cgColor : NSColor.black.cgColor)
    } else {
        context.scaleBy(x: CGFloat(pixels) / reference, y: CGFloat(pixels) / reference)
        drawAppIcon(in: context)
    }
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceSwitch-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try png(pixels: size * scale).write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

if CommandLine.arguments.count > 2 {
    let previews = URL(fileURLWithPath: CommandLine.arguments[2])
    try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
    for size in [1024, 64, 32, 18] {
        try png(pixels: size).write(to: previews.appendingPathComponent("app-\(size).png"))
    }
    for size in [18, 36] {
        try png(pixels: size, template: true).write(to: previews.appendingPathComponent("menu-\(size).png"))
        try png(pixels: size, template: true, dark: true).write(to: previews.appendingPathComponent("menu-dark-\(size).png"))
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", directory.path, "-o", destination.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 { exit(process.terminationStatus) }
