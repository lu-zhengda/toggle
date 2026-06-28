import AppKit

// Renders a 1024×1024 app icon (rounded blue squircle + white switch glyph)
// to the path given as argv[1].
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = 1024.0

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background squircle.
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                      xRadius: size * 0.225, yRadius: size * 0.225)
NSColor(srgbRed: 0.20, green: 0.47, blue: 0.96, alpha: 1).setFill()
bg.fill()

// White switch glyph (drawn as a white-tinted template image).
let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
if let base = NSImage(systemSymbolName: "switch.2", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let glyphSize = base.size
    let tinted = NSImage(size: glyphSize)
    tinted.lockFocus()
    NSColor.white.set()
    let r = NSRect(origin: .zero, size: glyphSize)
    base.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()
    tinted.draw(in: NSRect(x: (size - glyphSize.width) / 2,
                           y: (size - glyphSize.height) / 2,
                           width: glyphSize.width, height: glyphSize.height))
}

NSGraphicsContext.restoreGraphicsState()

if let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
} else {
    exit(1)
}
