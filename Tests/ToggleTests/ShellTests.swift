import XCTest
@testable import Toggle

final class ShellTests: XCTestCase {
    func testExecuteCapturesBothStreamsAndExitStatus() async {
        let result = await Shell.execute(
            "/bin/sh",
            ["-c", "printf stdout; printf stderr >&2; exit 7"],
            timeout: 2
        )

        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
        XCTAssertEqual(result.terminationStatus, 7)
        XCTAssertFalse(result.success)
        XCTAssertFalse(result.timedOut)
    }

    func testExecuteDrainsLargeStderrWithoutDeadlock() async {
        let result = await Shell.execute(
            "/bin/sh",
            ["-c", "/usr/bin/head -c 1048576 /dev/zero >&2"],
            timeout: 3
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stderr.utf8.count, 1_048_576)
    }

    func testExecuteTerminatesTimedOutProcess() async {
        let started = Date()
        let result = await Shell.execute("/bin/sleep", ["5"], timeout: 0.05)

        XCTAssertTrue(result.timedOut)
        XCTAssertFalse(result.success)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }

    func testLegacyRunReturnsEmptyOnFailure() {
        XCTAssertEqual(Shell.run("/usr/bin/false", []), "")
    }
}
