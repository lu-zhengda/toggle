import CoreWLAN

/// Public CoreWLAN-backed Wi-Fi power control. This avoids guessing an en0/en1
/// device name and does not depend on localized `networksetup` output.
enum WiFiPower {
    static func state() -> (available: Bool, isOn: Bool) {
        guard let interface = CWWiFiClient.shared().interface() else {
            return (false, false)
        }
        return (true, interface.powerOn())
    }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        guard let interface = CWWiFiClient.shared().interface() else { return false }
        do {
            try interface.setPower(on)
            return interface.powerOn() == on
        } catch {
            return false
        }
    }
}
