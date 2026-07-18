import XCTest
@testable import Toggle

final class SystemParsingTests: XCTestCase {
    func testVersionComparisonUsesNumericComponents() {
        XCTAssertTrue(SystemParsing.isVersion("v1.10.0", newerThan: "1.9.9"))
        XCTAssertFalse(SystemParsing.isVersion("v1.2.5", newerThan: "1.2.5"))
        XCTAssertFalse(SystemParsing.isVersion("v1.2", newerThan: "1.2.0"))
        XCTAssertTrue(SystemParsing.isVersion("2.0.0-beta.1", newerThan: "1.9.9"))
    }

    func testVersionParserIgnoresNonSemverTitleSuffixes() {
        XCTAssertEqual(SystemParsing.versionParts("v1.2.5"), [1, 2, 5])
        XCTAssertEqual(SystemParsing.versionParts("1.2.5 - 20 fixes"), [1, 2, 5])
        XCTAssertEqual(SystemParsing.versionParts("Toggle 1.2.5"), [])
    }

    func testDefaultsBooleanParsing() {
        XCTAssertTrue(SystemParsing.bool(fromDefaultsOutput: "1"))
        XCTAssertTrue(SystemParsing.bool(fromDefaultsOutput: "true\n"))
        XCTAssertFalse(SystemParsing.bool(fromDefaultsOutput: "0"))
        XCTAssertTrue(SystemParsing.bool(fromDefaultsOutput: "", default: true))
    }

    func testLowPowerModeParsing() {
        let enabled = """
        System-wide power settings:
         lowpowermode         1
        """
        XCTAssertEqual(SystemParsing.lowPowerModeValue(in: enabled), true)
        XCTAssertEqual(SystemParsing.lowPowerModeValue(in: "lowpowermode 0"), false)
        XCTAssertNil(SystemParsing.lowPowerModeValue(in: "sleep 1"))
    }
}
