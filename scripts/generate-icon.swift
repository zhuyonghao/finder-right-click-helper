import AppKit

// A native vector composition, rasterized at every required app-icon size.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate-icon.swift /path/to/AppIcon.iconset\n", stderr)
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func icon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "Icon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let backdrop = NSBezierPath(roundedRect: NSRect(x: 76, y: 76, width: 872, height: 872), xRadius: 194, yRadius: 194)
    NSGradient(starting: NSColor(red: 0.22, green: 0.44, blue: 0.98, alpha: 1),
               ending: NSColor(red: 0.08, green: 0.26, blue: 0.79, alpha: 1))!
        .draw(in: backdrop, angle: -75)
    let glow = NSBezierPath(roundedRect: NSRect(x: 77, y: 77, width: 870, height: 870), xRadius: 194, yRadius: 194)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    glow.lineWidth = 3
    glow.stroke()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let panel = NSBezierPath(roundedRect: NSRect(x: 214, y: 282, width: 596, height: 466), xRadius: 54, yRadius: 54)
    NSColor.white.setFill()
    panel.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(red: 0.88, green: 0.92, blue: 1, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 247, y: 580, width: 530, height: 125), xRadius: 26, yRadius: 26).fill()
    NSColor(red: 0.24, green: 0.43, blue: 0.85, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 280, y: 633, width: 59, height: 17), xRadius: 8, yRadius: 8).fill()
    NSBezierPath(roundedRect: NSRect(x: 301, y: 612, width: 17, height: 59), xRadius: 8, yRadius: 8).fill()
    NSBezierPath(roundedRect: NSRect(x: 373, y: 633, width: 300, height: 17), xRadius: 8, yRadius: 8).fill()
    NSColor(red: 0.77, green: 0.81, blue: 0.88, alpha: 1).setFill()
    for y in [499, 409] {
        NSBezierPath(roundedRect: NSRect(x: 280, y: y, width: 35, height: 35), xRadius: 10, yRadius: 10).fill()
        NSBezierPath(roundedRect: NSRect(x: 373, y: y + 9, width: 222, height: 17), xRadius: 8, yRadius: 8).fill()
    }

    let cursor = NSBezierPath()
    cursor.move(to: NSPoint(x: 652, y: 511))
    cursor.line(to: NSPoint(x: 648, y: 203))
    cursor.line(to: NSPoint(x: 721, y: 270))
    cursor.line(to: NSPoint(x: 778, y: 154))
    cursor.line(to: NSPoint(x: 847, y: 189))
    cursor.line(to: NSPoint(x: 789, y: 300))
    cursor.line(to: NSPoint(x: 889, y: 313))
    cursor.close()
    cursor.lineJoinStyle = .round
    NSColor.white.setStroke()
    cursor.lineWidth = 22
    cursor.stroke()
    NSColor(red: 0.10, green: 0.15, blue: 0.27, alpha: 1).setFill()
    cursor.fill()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Icon", code: 2)
    }
    return data
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 1 ? "" : "@2x"
        let name = "icon_\(points)x\(points)\(suffix).png"
        try icon(size: points * scale).write(to: output.appendingPathComponent(name))
    }
}
