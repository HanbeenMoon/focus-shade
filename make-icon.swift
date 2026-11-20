import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let size = CGFloat(pixels)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill(using: .copy)
        let inset = size * 0.12
        let face = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - 2 * inset,
                                                  height: size - 2 * inset),
                                xRadius: size * 0.16, yRadius: size * 0.16)
        NSColor(srgbRed: 0.13, green: 0.14, blue: 0.17, alpha: 1).setFill()
        face.fill()
        NSColor(srgbRed: 0.25, green: 0.26, blue: 0.30, alpha: 1).setStroke()
        face.lineWidth = max(0.6, size * 0.012)
        face.stroke()
        let dot = max(1.5, size * 0.074)
        NSColor(srgbRed: 0.83, green: 0.86, blue: 0.91, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.28, y: size * 0.66, width: dot, height: dot)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 1 ? "" : "@2x"
        let url = directory.appendingPathComponent("icon_\(base)x\(base)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
