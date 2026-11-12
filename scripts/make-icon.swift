// Draws Resources/AppIcon.icns: a notepad glyph on a plain rounded square.
import AppKit

let out = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: out).deletingPathExtension().appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func draw(_ size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.09
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.88, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18).fill()
    // ruled lines
    NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.86, alpha: 1).setFill()
    for i in 0..<5 {
        let y = rect.minY + rect.height * (0.2 + CGFloat(i) * 0.13)
        NSRect(x: rect.minX + rect.width * 0.16, y: y, width: rect.width * 0.68, height: max(1, s * 0.018)).fill()
    }
    // margin line
    NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.32, alpha: 1).setFill()
    NSRect(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.1,
           width: max(1, s * 0.014), height: rect.height * 0.8).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try draw(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try draw(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out]
try p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
