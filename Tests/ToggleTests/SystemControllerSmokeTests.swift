import XCTest
import Foundation
@testable import Toggle

final class SystemControllerSmokeTests: XCTestCase {
    @MainActor
    func testReadOnlySystemRefreshCompletes() async throws {
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw XCTSkip("Requires a logged-in Mac with real system services")
        }

        let controller = SystemController()
        controller.refresh()

        for _ in 0..<200 where !controller.hasLoadedState {
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertTrue(controller.hasLoadedState)
        XCTAssertFalse(controller.isRefreshing)
        XCTAssertTrue(controller.busyActions.isEmpty)
    }
}
