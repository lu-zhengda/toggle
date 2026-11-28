import SwiftUI
import AppKit

/// MenuBarExtra owns the window; this view only rounds its outer drawing surface.
struct PanelCorners: NSViewRepresentable {
    func makeNSView(context: Context) -> CornerView { CornerView() }
    func updateNSView(_ view: CornerView, context: Context) {}

    final class CornerView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, let frame = window.contentView?.superview else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            frame.wantsLayer = true
            frame.layer?.cornerRadius = 26
            frame.layer?.cornerCurve = .continuous
            frame.layer?.masksToBounds = true
            window.invalidateShadow()
        }
    }
}
