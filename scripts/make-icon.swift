import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceSwitch-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        NSColor(red: 0.11, green: 0.16, blue: 0.15, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 204, yRadius: 204).fill()
        NSColor(red: 0.71, green: 0.91, blue: 0.77, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 199, y: 242, width: 626, height: 562), xRadius: 100, yRadius: 100).fill()
        let text = "fn" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 330, weight: .medium), .foregroundColor: NSColor(red: 0.11, green: 0.16, blue: 0.15, alpha: 1)]
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (1024 - textSize.width) / 2, y: 328), withAttributes: attributes)
        NSColor(red: 0.71, green: 0.91, blue: 0.77, alpha: 1).setFill()
        for (index, height) in [36.0, 60, 84, 60, 36].enumerated() {
            NSBezierPath(roundedRect: NSRect(x: 416 + Double(index) * 40, y: 154 - height / 2, width: 20, height: height), xRadius: 10, yRadius: 10).fill()
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", directory.path, "-o", destination.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 { exit(process.terminationStatus) }
