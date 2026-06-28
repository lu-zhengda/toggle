import Foundation

/// Bridge to the private `CBTrueToneClient` (CoreBrightness) that backs True Tone.
/// Availability depends on the display hardware, so the tile is hidden when the
/// client reports the feature isn't available.
@objc private protocol CBTrueToneClientProtocol {
    func available() -> Bool
    func enabled() -> Bool
    func setEnabled(_ enabled: Bool) -> Bool
}

enum TrueTone {
    private static let client: CBTrueToneClientProtocol? = {
        guard let cls = NSClassFromString("CBTrueToneClient") as? NSObject.Type else {
            return nil
        }
        return unsafeBitCast(cls.init(), to: CBTrueToneClientProtocol.self)
    }()

    static var isAvailable: Bool { client?.available() ?? false }

    static func isEnabled() -> Bool { client?.enabled() ?? false }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        client?.setEnabled(enabled) ?? false
    }
}
