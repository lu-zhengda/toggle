import Foundation

/// Lightweight helpers for shelling out and running AppleScript.
enum Shell {
    /// Run a command, wait for it, return trimmed stdout (or "" on failure).
    @discardableResult
    static func run(_ launchPath: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }

    /// Fire-and-forget a command without blocking the UI.
    static func spawn(_ launchPath: String, _ args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = run(launchPath, args)
        }
    }

    /// Run an AppleScript snippet and return its result string.
    @discardableResult
    static func osascript(_ script: String) -> String {
        run("/usr/bin/osascript", ["-e", script])
    }
}
