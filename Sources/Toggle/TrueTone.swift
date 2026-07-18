import Foundation

/// Bridge to the private `CBTrueToneClient` (CoreBrightness) that backs True Tone.
/// Availability depends on the display hardware, so the tile is disabled when
/// the client reports that the feature is unavailable.
@objc private protocol CBTrueToneClientProtocol {
    func available() -> Bool
    func enabled() -> Bool
    func setEnabled(_ enabled: Bool) -> Bool
}

enum TrueTone {
    nonisolated(unsafe) private static let client: CBTrueToneClientProtocol? = {
        guard dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_LAZY | RTLD_LOCAL
        ) != nil else { return nil }
        guard let cls = NSClassFromString("CBTrueToneClient") as? NSObject.Type else {
            return nil
        }
        let instance = cls.init()
        guard instance.responds(to: NSSelectorFromString("available")),
              instance.responds(to: NSSelectorFromString("enabled")),
              instance.responds(to: NSSelectorFromString("setEnabled:")) else {
            return nil
        }
        return unsafeBitCast(instance, to: CBTrueToneClientProtocol.self)
    }()

    private static let queue = DispatchQueue(label: "com.local.toggle.true-tone")

    static var isAvailable: Bool { queue.sync { client?.available() ?? false } }

    static func isEnabled() -> Bool { queue.sync { client?.enabled() ?? false } }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        queue.sync { client?.setEnabled(enabled) ?? false }
    }
}
