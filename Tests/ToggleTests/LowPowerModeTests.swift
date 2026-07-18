import AppKit
import XCTest
@testable import Toggle

final class LowPowerModeTests: XCTestCase {
    func testBooleanArgumentsAreStrict() {
        XCTAssertEqual(LowPowerMode.argument(for: true), "1")
        XCTAssertEqual(LowPowerMode.argument(for: false), "0")
    }

    func testPrivilegedScriptCompilesWithoutExecuting() {
        let script = NSAppleScript(source: LowPowerMode.scriptSource)
        var error: NSDictionary?

        XCTAssertNotNil(script)
        XCTAssertEqual(script?.compileAndReturnError(&error), true)
        XCTAssertNil(error)
    }

    func testHandlerReceivesStateAsAnAppleEventArgument() {
        let script = NSAppleScript(source: """
        on echoState(requestedState)
            return requestedState as text
        end echoState
        """)!

        let result = LowPowerMode.execute(
            script: script,
            handler: "echoState",
            argument: "1"
        )

        XCTAssertNil(result.error)
        XCTAssertEqual(result.output?.stringValue, "1")
    }

    func testResultClassificationDistinguishesCancellationAndFailure() {
        let cancellation = NSDictionary(dictionary: [
            NSAppleScript.errorNumber: NSNumber(value: -128),
        ])
        XCTAssertEqual(
            LowPowerMode.classify(output: nil, error: cancellation),
            .cancelled
        )

        let failure = NSDictionary(dictionary: [
            NSAppleScript.errorNumber: NSNumber(value: -1),
            NSAppleScript.errorMessage: "Example failure",
        ])
        XCTAssertEqual(
            LowPowerMode.classify(output: nil, error: failure),
            .failure("Example failure")
        )
    }
}
