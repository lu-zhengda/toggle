import AppKit

// Package the selected rocker artwork inside a clean, consistently sized macOS tile.
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
guard let artwork = NSImage(contentsOfFile: "Assets/RockerArtwork.png"),
      let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("Cannot load rocker artwork or allocate app icon bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let rect = NSRect(x: 64, y: 64, width: 896, height: 896)
let tile = NSBezierPath(roundedRect: rect, xRadius: 202, yRadius: 202)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowBlurRadius = 18
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
NSColor(srgbRed: 0.94, green: 0.93, blue: 0.90, alpha: 1).setFill()
tile.fill()
NSGraphicsContext.restoreGraphicsState()

tile.addClip()
// Trim the generated artwork's transparent margin; the native path owns the outer edge.
artwork.draw(in: rect,
             from: NSRect(x: artwork.size.width * 132 / 1254,
                          y: artwork.size.height * 146 / 1254,
                          width: artwork.size.width * 988 / 1254,
                          height: artwork.size.height * 970 / 1254),
             operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Cannot encode app icon PNG")
}
try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
