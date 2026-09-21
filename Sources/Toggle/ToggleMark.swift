import AppKit

/// Monochrome counterpart of the app icon's upright rocker switch.
enum ToggleMark {
    static func path(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: NSRect(x: 5, y: 1, width: 10, height: 18),
                                xRadius: 3, yRadius: 3)
        path.appendRect(NSRect(x: 5, y: 9.5, width: 10, height: 1))
        path.appendOval(in: NSRect(x: 8.5, y: 12.5, width: 3, height: 3))
        path.windingRule = .evenOdd

        var transform = AffineTransform(translationByX: rect.minX, byY: rect.minY)
        transform.scale(x: rect.width / 20, y: rect.height / 20)
        path.transform(using: transform)
        return path
    }

    @MainActor static let menuBarImage: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            NSColor.black.setFill()
            path(in: rect).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Toggle"
        return image
    }()
}
