import AppKit
import XCTest
@testable import Toggle

final class PanelCornersTests: XCTestCase {
    @MainActor
    func testCornersApplyWhenAttachedToWindow() throws {
        _ = NSApplication.shared
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 284, height: 364),
                            styleMask: [.borderless], backing: .buffered, defer: false)
        let view = PanelCorners.CornerView()
        panel.contentView?.addSubview(view)
        let layer = try XCTUnwrap(panel.contentView?.superview?.layer)
        XCTAssertEqual(layer.cornerRadius, 20)
        XCTAssertEqual(layer.cornerCurve, .continuous)
        XCTAssertTrue(layer.masksToBounds)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        view.removeFromSuperview()
    }
}
