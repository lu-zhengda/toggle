import Foundation
import Darwin

/// The complete outcome of launching a subprocess.
///
/// `stdout` and `stderr` preserve the command's output verbatim. A command only
/// succeeds when it launched, exited with status zero, and did not time out.
struct CommandResult: Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32?
    let launchError: String?
    let timedOut: Bool

    var success: Bool {
        launchError == nil && !timedOut && terminationStatus == 0
    }
}

/// Lightweight helpers for shelling out and running AppleScript.
enum Shell {
    static let defaultTimeout: TimeInterval = 30

    private static let terminationGracePeriod: TimeInterval = 1
    private static let executionQueue = DispatchQueue(
        label: "com.local.toggle.shell",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// Run a command without blocking the caller's actor.
    static func execute(
        _ launchPath: String,
        _ args: [String],
        timeout: TimeInterval = defaultTimeout
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            executionQueue.async {
                continuation.resume(returning: executeBlocking(launchPath, args, timeout: timeout))
            }
        }
    }

    /// Run a command, wait for it, return trimmed stdout (or "" on failure).
    @discardableResult
    static func run(_ launchPath: String, _ args: [String]) -> String {
        let result = executeBlocking(launchPath, args, timeout: defaultTimeout)
        guard result.success else { return "" }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func executeBlocking(
        _ launchPath: String,
        _ args: [String],
        timeout: TimeInterval
    ) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let termination = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in termination.signal() }

        do {
            try process.run()
        } catch {
            return CommandResult(
                stdout: "",
                stderr: "",
                terminationStatus: nil,
                launchError: error.localizedDescription,
                timedOut: false
            )
        }

        // Both streams must be drained concurrently. Reading only stdout can
        // deadlock if the child fills the stderr pipe before it exits.
        let stdout = LockedData()
        let stderr = LockedData()
        let readers = DispatchGroup()
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stdout.store(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stderr.store(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }

        let boundedTimeout = max(0, timeout)
        let timedOut = termination.wait(timeout: .now() + boundedTimeout) == .timedOut
        if timedOut, process.isRunning {
            process.terminate()
            if termination.wait(timeout: .now() + terminationGracePeriod) == .timedOut,
               process.isRunning {
                Darwin.kill(process.processIdentifier, SIGKILL)
                _ = termination.wait(timeout: .now() + terminationGracePeriod)
            }
        }

        // A killed process normally closes both pipes immediately. Bound this
        // wait as a final safeguard against a descendant retaining a pipe fd.
        if readers.wait(timeout: .now() + terminationGracePeriod) == .timedOut {
            try? stdoutPipe.fileHandleForReading.close()
            try? stderrPipe.fileHandleForReading.close()
            _ = readers.wait(timeout: .now() + terminationGracePeriod)
        }

        let status = process.isRunning ? nil : process.terminationStatus
        return CommandResult(
            stdout: String(decoding: stdout.load(), as: UTF8.self),
            stderr: String(decoding: stderr.load(), as: UTF8.self),
            terminationStatus: status,
            launchError: nil,
            timedOut: timedOut
        )
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

/// Dispatch-group synchronization establishes ordering for reads, while this
/// lock also keeps the storage valid under Swift's Sendable model.
private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ value: Data) {
        lock.lock()
        data = value
        lock.unlock()
    }

    func load() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
