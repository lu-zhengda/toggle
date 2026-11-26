import Foundation

/// Bridge to the private `CBBlueLightClient` class (CoreBrightness) that backs
/// the Night Shift feature. We declare just the selectors we need and message
/// the runtime class directly. Everything is best-effort and guarded.
@objc private protocol CBBlueLightClientProtocol {
    func setEnabled(_ enabled: Bool) -> Bool
    /// Fills a StatusData struct; we read it via a raw pointer.
    func getBlueLightStatus(_ status: UnsafeMutableRawPointer) -> Bool
}

enum NightShift {
    nonisolated(unsafe) private static let client: CBBlueLightClientProtocol? = {
        guard dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_LAZY | RTLD_LOCAL
        ) != nil else { return nil }
        guard let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type else {
            return nil
        }
        let instance = cls.init()
        guard instance.responds(to: NSSelectorFromString("setEnabled:")),
              instance.responds(to: NSSelectorFromString("getBlueLightStatus:")) else {
            return nil
        }
        return unsafeBitCast(instance, to: CBBlueLightClientProtocol.self)
    }()

    private static let queue = DispatchQueue(label: "com.zhengdalu.toggle.night-shift")

    static var isAvailable: Bool { queue.sync { client != nil } }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        queue.sync {
            guard let client else { return false }
            return client.setEnabled(enabled)
        }
    }

    /// Read the current enabled flag. The CoreBrightness status blob starts with
    /// an `active` BOOL followed by an `enabled` BOOL; byte offset 1 is the one
    /// that tracks the live Night Shift state.
    static func isEnabled() -> Bool {
        queue.sync {
            guard let client else { return false }
            var buffer = [UInt8](repeating: 0, count: 64)
            let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
                guard let base = raw.baseAddress else { return false }
                return client.getBlueLightStatus(base)
            }
            guard ok else { return false }
            return buffer[1] != 0
        }
    }
}