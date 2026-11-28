import Foundation

struct DropdownOption: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let isSelected: Bool
    var isAction: Bool = false
}

struct DeviceChoice: Equatable, Sendable {
    let id: String
    let title: String
}

enum AirDropMenu {
    static let choices = ["Contacts Only", "Everyone", "Off"]

    static func isOn(_ mode: String) -> Bool {
        mode != "Off"
    }

    static func toggledMode(current: String) -> String {
        isOn(current) ? "Off" : "Contacts Only"
    }

    static func options(selected: String) -> [DropdownOption] {
        choices.map { mode in
            DropdownOption(id: mode, title: mode, isSelected: mode == selected)
        }
    }
}

enum KeepAwakeMenu {
    static func options(minutes: [Int], isOn: Bool, chosenMinutes: Int?) -> [DropdownOption] {
        minutes.map { value in
            DropdownOption(
                id: String(value),
                title: KeepAwakeDuration.name(for: value),
                isSelected: isSelected(minutes: value, isOn: isOn, chosenMinutes: chosenMinutes)
            )
        }
    }

    static func isSelected(minutes: Int, isOn: Bool, chosenMinutes: Int?) -> Bool {
        guard isOn else { return false }
        if minutes == 0 {
            return chosenMinutes == nil || chosenMinutes == 0
        }
        return chosenMinutes == minutes
    }

    static func valueText(isOn: Bool, remainingMinutes: Int?, indefinite: Bool) -> String? {
        guard isOn else { return nil }
        if indefinite { return "Indefinitely" }
        guard let remainingMinutes else { return "Indefinitely" }
        if remainingMinutes >= 60 {
            let hours = remainingMinutes / 60
            let mins = remainingMinutes % 60
            if mins == 0 { return "\(hours) hr left" }
            return "\(hours) hr \(mins) min left"
        }
        return "\(remainingMinutes) min left"
    }

    static func accessibilityValue(isOn: Bool, remainingMinutes: Int?, indefinite: Bool) -> String {
        guard isOn else { return "Off" }
        if indefinite || remainingMinutes == nil { return "On indefinitely" }
        return "On, \(remainingMinutes ?? 0) minutes remaining"
    }

    static func remainingMinutes(until: Date, now: Date) -> Int {
        let seconds = until.timeIntervalSince(now)
        if seconds <= 0 { return 0 }
        return Int(ceil(seconds / 60))
    }
}

enum DeviceMenu {
    static let bluetoothSettingsID = "bluetooth-settings"

    static func options(
        devices: [DeviceChoice],
        selectedID: String?,
        trailingAction: DeviceChoice? = nil
    ) -> [DropdownOption] {
        var options = devices.map { device in
            DropdownOption(
                id: device.id,
                title: device.title,
                isSelected: device.id == selectedID && trailingAction?.id != device.id
            )
        }
        if let trailingAction {
            options.append(
                DropdownOption(
                    id: trailingAction.id,
                    title: trailingAction.title,
                    isSelected: false,
                    isAction: true
                )
            )
        }
        return options
    }
}

enum MenuKeyboard {
    static func highlight(current: Int, count: Int, delta: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(0, current + delta), count - 1)
    }
}
