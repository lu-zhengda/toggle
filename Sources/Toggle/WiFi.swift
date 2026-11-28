import CoreWLAN

/// Public CoreWLAN-backed Wi-Fi power control. This avoids guessing an en0/en1
/// device name and does not depend on localized `networksetup` output.
enum WiFiPower {
    static func state() -> (available: Bool, isOn: Bool, networkName: String?) {
        guard let interface = CWWiFiClient.shared().interface() else {
            return (false, false, nil)
        }
        let isOn = interface.powerOn()
        guard isOn else { return (true, false, nil) }
        let trimmed = interface.ssid()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let networkName = trimmed?.isEmpty == false ? trimmed : nil
        return (true, true, networkName)
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
