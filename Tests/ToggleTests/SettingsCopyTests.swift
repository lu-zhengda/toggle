import XCTest

/// Settings and panel chrome must not ship explanatory helper copy.
final class SettingsCopyTests: XCTestCase {
    func testSourcesOmitHelperCopy() throws {
        let directory = try sourcesDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        let banned = [
            "Drag to reorder",
            "Uncheck to hide",
            "Remembered per user",
            "Updates as you reorder",
            "Checked durations appear",
            "Equivalent to caffeinate",
            "Lets Toggle",
            "Right-click the coffee",
            "macOS prompts",
            "footnote",
        ]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for phrase in banned {
                XCTAssertFalse(
                    text.localizedCaseInsensitiveContains(phrase),
                    "\(file.lastPathComponent) contains helper copy"
                )
            }
        }
    }

    private func sourcesDirectory() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            let candidate = url.appendingPathComponent("Sources/Toggle")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
            url.deleteLastPathComponent()
        }
        struct MissingSources: Error {}
        throw MissingSources()
    }
}
