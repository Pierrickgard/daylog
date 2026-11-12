// Draws the app icon: a green rounded square with a small log, one done item and two entries.
//   swift scripts/make-icon.swift build/AppIcon.icns     -> .icns for the app bundle
//   swift scripts/make-icon.swift docs/icon.png 512      -> a single PNG
import AppKit

func draw(_ size: Int) -> Data {
    let s = CGFloat(size) / 1024 // everything below is drawn on a 1024 grid
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: a)
    }

    // Body, on Apple's 824 px icon grid, with a soft drop shadow.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 24
    shadow.set()
    rgb(0x23845F).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(starting: rgb(0x4FCB9F), ending: rgb(0x1C7356))!.draw(in: body, angle: -90)
    // light from the top
    NSGradient(starting: NSColor(white: 1, alpha: 0.16), ending: NSColor(white: 1, alpha: 0))!
        .draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Three rows: a checked box, then two bullets. Lines get shorter, like a log being written.
    let left: CGFloat = 222
    let rows: [(y: CGFloat, width: CGFloat)] = [(650, 380), (500, 440), (350, 280)]
    let white = NSColor.white
    let lineHeight: CGFloat = 54

    for (i, row) in rows.enumerated() {
        let line = NSRect(x: left + 140, y: row.y - lineHeight / 2, width: row.width, height: lineHeight)
        (i == 0 ? NSColor(white: 1, alpha: 0.55) : white).setFill()
        NSBezierPath(roundedRect: line, xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()

        if i == 0 {
            let box = NSRect(x: left, y: row.y - 50, width: 100, height: 100)
            white.setFill()
            NSBezierPath(roundedRect: box, xRadius: 26, yRadius: 26).fill()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: left + 24, y: row.y + 2))
            check.line(to: NSPoint(x: left + 44, y: row.y - 20))
            check.line(to: NSPoint(x: left + 78, y: row.y + 24))
            check.lineWidth = 17
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            rgb(0x23845F).setStroke()
            check.stroke()
        } else {
            white.setFill()
            NSBezierPath(ovalIn: NSRect(x: left + 22, y: row.y - 28, width: 56, height: 56)).fill()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)

if out.pathExtension == "png" {
    let size = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 1024
    try draw(size).write(to: out)
} else {
    let iconset = out.deletingPathExtension().appendingPathExtension("iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        try draw(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
        try draw(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
    try p.run()
    p.waitUntilExit()
    try? FileManager.default.removeItem(at: iconset)
}
