import CoreAudio
import Foundation

extension SystemController {
    var toggleAvailability: ToggleAvailability {
        ToggleAvailability(
            wifiAvailable: wifiAvailable,
            bluetoothAvailable: bluetoothAvailable,
            airPodsAvailable: airPodsAvailable,
            nightShiftAvailable: nightShiftAvailable,
            trueToneAvailable: trueToneAvailable,
            lowPowerModeAvailable: lowPowerModeAvailable
        )
    }
}

enum ToggleActions {
    @MainActor
    static func isOn(_ id: ToggleID, controller: SystemController) -> Bool? {
        switch id {
        case .wifi: controller.wifi
        case .bluetooth: controller.bluetooth
        case .airDrop: AirDropMenu.isOn(controller.airDropMode)
        case .airPods: controller.airPodsConnected
        case .darkMode: controller.darkMode
        case .nightShift: controller.nightShift
        case .trueTone: controller.trueTone
        case .mute: controller.muted
        case .keepAwake: controller.keepAwake
        case .lowPowerMode: controller.lowPowerMode
        case .doNotDisturb: nil
        case .stageManager: controller.stageManager
        case .hideDesktopIcons: controller.hideDesktopIcons
        case .hiddenFiles: controller.showHiddenFiles
        case .fileExtensions: controller.showFileExtensions
        case .dockAutohide: controller.dockAutohide
        }
    }

    @MainActor
    static func subtitle(_ id: ToggleID, controller: SystemController) -> String? {
        switch id {
        case .wifi:
            guard controller.wifi else { return nil }
            guard let name = controller.wifiNetworkName, !name.isEmpty else { return nil }
            return name
        case .airDrop:
            return controller.airDropMode
        case .airPods:
            return controller.selectedAirPods?.name
        case .mute:
            return controller.audioDevices.first { $0.id == controller.audioOutputID }?.name
        case .keepAwake:
            let remaining = controller.keepAwakeUntil.map {
                KeepAwakeMenu.remainingMinutes(until: $0, now: Date())
            }
            return KeepAwakeMenu.valueText(
                isOn: controller.keepAwake,
                remainingMinutes: remaining,
                indefinite: controller.keepAwake && controller.keepAwakeUntil == nil
            )
        case .bluetooth, .darkMode, .nightShift, .trueTone, .lowPowerMode, .doNotDisturb,
             .stageManager, .hideDesktopIcons, .hiddenFiles, .fileExtensions, .dockAutohide:
            return nil
        }
    }

    @MainActor
    static func accessibilityValue(_ id: ToggleID, controller: SystemController) -> String {
        if id == .keepAwake {
            let remaining = controller.keepAwakeUntil.map {
                KeepAwakeMenu.remainingMinutes(until: $0, now: Date())
            }
            return KeepAwakeMenu.accessibilityValue(
                isOn: controller.keepAwake,
                remainingMinutes: remaining,
                indefinite: controller.keepAwake && controller.keepAwakeUntil == nil
            )
        }
        if id == .doNotDisturb { return "Action" }
        if let subtitle = subtitle(id, controller: controller), id == .airDrop || id == .mute || id == .wifi || id == .airPods {
            let state = isOn(id, controller: controller) == true ? "On" : "Off"
            return "\(state), \(subtitle)"
        }
        return isOn(id, controller: controller) == true ? "On" : "Off"
    }

    static func accessibilityHint(_ id: ToggleID) -> String {
        if id.hasDropdown { return "Shows choices" }
        if id == .doNotDisturb { return "Toggles Do Not Disturb" }
        return "Toggles \(id.title)"
    }

    @MainActor
    static func help(_ id: ToggleID, controller: SystemController) -> String {
        if let subtitle = subtitle(id, controller: controller) {
            return "\(id.title), \(subtitle)"
        }
        return id.title
    }

    @MainActor
    static func trigger(_ id: ToggleID, controller: SystemController) {
        switch id {
        case .wifi: controller.toggleWifi()
        case .bluetooth: controller.toggleBluetooth()
        case .airDrop: controller.setAirDrop(AirDropMenu.toggledMode(current: controller.airDropMode))
        case .airPods: controller.toggleAirPods()
        case .darkMode: controller.toggleDarkMode()
        case .nightShift: controller.toggleNightShift()
        case .trueTone: controller.toggleTrueTone()
        case .mute: controller.toggleMute()
        case .keepAwake: controller.toggleKeepAwake()
        case .lowPowerMode: controller.toggleLowPowerMode()
        case .doNotDisturb: controller.toggleDoNotDisturb()
        case .stageManager: controller.toggleStageManager()
        case .hideDesktopIcons: controller.toggleHideDesktopIcons()
        case .hiddenFiles: controller.toggleHiddenFiles()
        case .fileExtensions: controller.toggleFileExtensions()
        case .dockAutohide: controller.toggleDockAutohide()
        }
    }

    @MainActor
    static func options(
        for id: ToggleID,
        controller: SystemController,
        menuMinutes: [Int]
    ) -> [DropdownOption] {
        switch id {
        case .airDrop:
            AirDropMenu.options(selected: controller.airDropMode)
        case .airPods:
            DeviceMenu.options(
                devices: controller.airPodsDevices.map { DeviceChoice(id: $0.id, title: $0.name) },
                selectedID: controller.airPodsSelectedID,
                trailingAction: DeviceChoice(id: DeviceMenu.bluetoothSettingsID, title: "Bluetooth Settings…")
            )
        case .keepAwake:
            KeepAwakeMenu.options(
                minutes: menuMinutes,
                isOn: controller.keepAwake,
                chosenMinutes: controller.keepAwakeChosenMinutes
            )
        case .mute:
            DeviceMenu.options(
                devices: controller.audioDevices.map { DeviceChoice(id: String($0.id), title: $0.name) },
                selectedID: String(controller.audioOutputID)
            )
        default:
            []
        }
    }

    @MainActor
    static func apply(_ option: DropdownOption, for id: ToggleID, controller: SystemController) {
        switch id {
        case .airDrop:
            controller.setAirDrop(option.id)
        case .airPods:
            if option.id == DeviceMenu.bluetoothSettingsID {
                controller.openBluetoothSettings()
            } else {
                controller.selectAirPodsDevice(option.id)
            }
        case .keepAwake:
            if let minutes = Int(option.id) {
                controller.setKeepAwake(true, minutes: minutes)
            }
        case .mute:
            if let raw = UInt32(option.id) {
                controller.selectAudioDevice(AudioDeviceID(raw))
            }
        default:
            break
        }
    }

    @MainActor
    static func perform(_ action: QuickAction, controller: SystemController) {
        switch action {
        case .screenSaver: controller.startScreenSaver()
        case .lockScreen: controller.lockScreen()
        case .sleepDisplay: controller.sleepDisplay()
        case .more: break
        }
    }
}
