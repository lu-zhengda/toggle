import Foundation

/// Lock the current session through the same private login-framework function
/// used by macOS system UI. Resolving it dynamically keeps app launch safe if
/// Apple removes or renames the function in a future macOS release.
enum ScreenLock {
    private typealias LockFn = @convention(c) () -> Void

    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/login.framework/login",
        RTLD_LAZY | RTLD_LOCAL
    )

    private static let lockFn: LockFn? = {
        guard let handle,
              let symbol = dlsym(handle, "SACLockScreenImmediate")
        else { return nil }
        return unsafeBitCast(symbol, to: LockFn.self)
    }()

    static var isAvailable: Bool { lockFn != nil }

    @discardableResult
    static func lock() -> Bool {
        guard let lockFn else { return false }
        lockFn()
        return true
    }
}
