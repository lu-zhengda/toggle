import Foundation

/// Bridge to the private `CBBlueLightClient` class (CoreBrightness) that backs
/// the Night Shift feature. We declare just the selectors we need and message
/// the runtime class directly. Everything is best-effort and guarded.
@objc private protocol CBBlueLightClientProtocol {
    func setEnabled(_ enabled: Bool) -> Bool
    func setStrength(_ strength: Float, commit: Bool) -> Bool
    // getBlueLightStatus: fills a StatusData struct; we read it via a raw pointer.
    func getBlueLightStatus(_ status: UnsafeMutableRawPointer) -> Bool
}

enum NightShift {
    private static let client: CBBlueLightClientProtocol? = {
        guard let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type else {
            return nil
        }
        let instance = cls.init()
        return unsafeBitCast(instance, to: CBBlueLightClientProtocol.self)
    }()

    static var isAvailable: Bool { client != nil }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard let client else { return false }
        if enabled {
            _ = client.setStrength(0.5, commit: true)
        }
        return client.setEnabled(enabled)
    }

    /// Read the current enabled flag. The CoreBrightness status blob starts with
    /// an `active` BOOL followed by an `enabled` BOOL; byte offset 1 is the one
    /// that tracks the live Night Shift state.
    static func isEnabled() -> Bool {
        guard let client else { return false }
        var buffer = [UInt8](repeating: 0, count: 64)
        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            client.getBlueLightStatus(raw.baseAddress!)
        }
        guard ok else { return false }
        // buffer[0] = active (currently dimming), buffer[1] = enabled toggle.
        return buffer[1] != 0
    }
}
