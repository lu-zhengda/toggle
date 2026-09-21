import AppKit
import XCTest
@testable import Toggle

final class ToggleMarkTests: XCTestCase {
    @MainActor
    func testRockerKeepsItsSilhouetteAndTransparentDetailsAtEverySize() {
        XCTAssertTrue(ToggleMark.menuBarImage.isTemplate)
        XCTAssertEqual(ToggleMark.menuBarImage.size, NSSize(width: 20, height: 20))

        for size: CGFloat in [20, 40, 720] {
            let rect = NSRect(x: 64, y: 64, width: size, height: size)
            let path = ToggleMark.path(in: rect)
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: rect.minX + x * size / 20, y: rect.minY + y * size / 20)
            }
            XCTAssertTrue(path.contains(point(7, 14)), "Upper rocker must stay visible")
            XCTAssertTrue(path.contains(point(10, 5)), "Lower rocker must stay visible")
            XCTAssertFalse(path.contains(point(10, 14)), "Indicator must remain transparent")
            XCTAssertFalse(path.contains(point(10, 10)), "Center seam must remain transparent")
            XCTAssertFalse(path.contains(point(4, 5)), "Outside the rocker must remain empty")
            XCTAssertTrue(rect.contains(path.bounds))
        }
    }
}
