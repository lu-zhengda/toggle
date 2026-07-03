import Foundation
import SwiftUI
import AppKit
import CoreAudio
import IOKit.pwr_mgt

/// Owns the live state of every switch and performs the underlying system action.
@MainActor
final class SystemController: ObservableObject {

    // Stateful toggles
    @Published var darkMode = false
    @Published var hideDesktopIcons = false
    @Published var showHiddenFiles = false
    @Published var keepAwake = false
    @Published var keepAwakeUntil: Date?
    @Published var muted = false
    @Published var nightShift = false
    @Published var trueTone = false
    @Published var wifi = false
    @Published var bluetooth = false
    @Published var airPodsConnected = false
    @Published var doNotDisturb = false
    @Published var showFileExtensions = false
    @Published var dockAutohide = false
    @Published var stageManager = false
    @Published var audioDevices: [AudioDevice] = []
    @Published var audioOutputID: AudioDeviceID = 0
    @Published var airDropMode = "Off"

    var audioOutputName: String {
        audioDevices.first { $0.id == audioOutputID }?.name ?? "Output"
    }

    // Feature availability (drives whether a tile is shown)
    let nightShiftAvailable = NightShift.isAvailable
    let bluetoothAvailable = BluetoothPower.isAvailable
    // Computed so it reflects the current display (True Tone depends on hardware).
    var trueToneAvailable: Bool { TrueTone.isAvailable }
    var airPodsAvailable: Bool { AirPods.isAvailable }

    private var assertionIDs: [IOPMAssertionID] = []
    private var keepAwakeTimer: DispatchWorkItem?

    /// The Wi-Fi hardware device (en0/en1/…), discovered once.
    nonisolated private static let wifiDevice: String = {
        let out = Shell.run("/usr/sbin/networksetup", ["-listallhardwareports"])
        let lines = out.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() where line.contains("Wi-Fi") {
            if i + 1 < lines.count, let r = lines[i + 1].range(of: "Device: ") {
                return String(lines[i + 1][r.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return "en0"
    }()

    init() {
        refresh()
    }

    /// Re-read the world so the UI matches reality when the panel opens.
    func refresh() {
        // These spawn subprocesses / hit IOBluetooth, which is slow. Run them off
        // the main thread so opening the panel never blocks the UI, then publish
        // the results back on the main actor.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let dark = self.readDarkMode()
            let iconsVisible = self.readDesktopIconsVisible()
            let hidden = self.readShowHiddenFiles()
            let isMuted = self.readMuted()
            let ns = NightShift.isEnabled()
            let tt = TrueTone.isEnabled()
            let wifiOn = self.readWifi()
            let btOn = BluetoothPower.isOn()
            let airpods = AirPods.isConnected()
            let exts = self.readFileExtensions()
            let dock = self.readDockAutohide()
            let stage = self.readStageManager()
            let audioDevs = AudioOutput.outputDevices()
            let audioCur = AudioOutput.currentDeviceID()
            let airdrop = self.readAirDrop()
            await MainActor.run {
                self.darkMode = dark
                self.hideDesktopIcons = !iconsVisible
                self.showHiddenFiles = hidden
                self.muted = isMuted
                self.nightShift = ns
                self.trueTone = tt
                self.wifi = wifiOn
                self.bluetooth = btOn
                self.airPodsConnected = airpods
                self.showFileExtensions = exts
                self.dockAutohide = dock
                self.stageManager = stage
                self.audioDevices = audioDevs
                self.audioOutputID = audioCur
                self.airDropMode = airdrop
            }
        }
        // keepAwake / doNotDisturb reflect our own state, no need to re-read.
    }

    // MARK: - Dark Mode

    func toggleDarkMode() {
        let target = !darkMode
        Shell.osascript(
            "tell application \"System Events\" to tell appearance preferences to set dark mode to \(target)"
        )
        darkMode = target
    }

    nonisolated private func readDarkMode() -> Bool {
        Shell.run("/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"])
            .lowercased() == "dark"
    }

    // MARK: - Hide Desktop Icons

    func toggleHideDesktopIcons() {
        let hide = !hideDesktopIcons // hide == don't create desktop
        Shell.run("/usr/bin/defaults",
                  ["write", "com.apple.finder", "CreateDesktop", "-bool", hide ? "false" : "true"])
        Shell.run("/usr/bin/killall", ["Finder"])
        hideDesktopIcons = hide
    }

    nonisolated private func readDesktopIconsVisible() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.finder", "CreateDesktop"])
        // Missing key -> default true (icons visible).
        if value.isEmpty { return true }
        return value != "0" && value.lowercased() != "false"
    }

    // MARK: - Show Hidden Files

    func toggleHiddenFiles() {
        let show = !showHiddenFiles
        Shell.run("/usr/bin/defaults",
                  ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", show ? "true" : "false"])
        Shell.run("/usr/bin/killall", ["Finder"])
        showHiddenFiles = show
    }

    nonisolated private func readShowHiddenFiles() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.finder", "AppleShowAllFiles"])
        return value == "1" || value.lowercased() == "true"
    }

    // MARK: - Keep Awake (caffeinate via IOKit power assertion)

    /// Toggle indefinitely, or pass `minutes` to auto-release after a timer.
    func setKeepAwake(_ on: Bool, minutes: Int? = nil) {
        keepAwakeTimer?.cancel()
        keepAwakeTimer = nil
        for id in assertionIDs { IOPMAssertionRelease(id) }
        assertionIDs = []
        keepAwakeUntil = nil
        keepAwake = false
        guard on else { return }

        // caffeinate -i -d: prevent both system idle sleep and display sleep.
        let types = [
            kIOPMAssertionTypePreventUserIdleSystemSleep,
            kIOPMAssertionTypePreventUserIdleDisplaySleep,
        ]
        for type in types {
            var assertionID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Toggle: Keep Awake" as CFString,
                &assertionID
            )
            if result == kIOReturnSuccess { assertionIDs.append(assertionID) }
        }
        guard !assertionIDs.isEmpty else { return }
        keepAwake = true

        if let minutes {
            keepAwakeUntil = Date().addingTimeInterval(Double(minutes) * 60)
            let work = DispatchWorkItem { [weak self] in self?.setKeepAwake(false) }
            keepAwakeTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(minutes) * 60, execute: work)
        }
    }

    func toggleKeepAwake() { setKeepAwake(!keepAwake) }

    // MARK: - Mute

    func toggleMute() {
        let target = !muted
        Shell.osascript("set volume output muted \(target)")
        muted = target
    }

    nonisolated private func readMuted() -> Bool {
        Shell.osascript("output muted of (get volume settings)").lowercased() == "true"
    }

    // MARK: - Night Shift

    func toggleNightShift() {
        let target = !nightShift
        if NightShift.setEnabled(target) {
            nightShift = target
        }
    }

    // MARK: - True Tone

    func toggleTrueTone() {
        let target = !trueTone
        if TrueTone.setEnabled(target) {
            trueTone = target
        }
    }

    // MARK: - Wi-Fi

    func toggleWifi() {
        let target = !wifi
        Shell.run("/usr/sbin/networksetup",
                  ["-setairportpower", Self.wifiDevice, target ? "on" : "off"])
        wifi = target
    }

    nonisolated private func readWifi() -> Bool {
        Shell.run("/usr/sbin/networksetup", ["-getairportpower", Self.wifiDevice])
            .lowercased().contains(": on")
    }

    // MARK: - Bluetooth

    func toggleBluetooth() {
        let target = !bluetooth
        // Turning Bluetooth off can disconnect the keyboard/mouse — confirm first.
        if !target, !confirmBluetoothOff() { return }
        BluetoothPower.set(target)
        bluetooth = target
    }

    private func confirmBluetoothOff() -> Bool {
        let suppressKey = "suppressBluetoothWarning"
        if UserDefaults.standard.bool(forKey: suppressKey) { return true }

        let names = BluetoothPower.connectedDeviceNames()
        if names.isEmpty { return true } // nothing to lose

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Turn off Bluetooth?"
        var info = "This will disconnect \(names.count) connected "
            + "device\(names.count == 1 ? "" : "s"): \(names.joined(separator: ", "))."
        if BluetoothPower.hasConnectedInputDevice() {
            info += "\n\nThat includes a Bluetooth keyboard or mouse. You may lose input "
                + "until you turn Bluetooth back on using a built-in or wired device."
        }
        alert.informativeText = info
        alert.addButton(withTitle: "Cancel") // default — Return cancels
        let off = alert.addButton(withTitle: "Turn Off Bluetooth")
        off.hasDestructiveAction = true
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't warn me again"

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: suppressKey)
        }
        return response == .alertSecondButtonReturn
    }

    // MARK: - AirPods quick-connect

    func toggleAirPods() {
        let target = !airPodsConnected
        // Optimistic UI; the open/close call blocks for a couple seconds.
        airPodsConnected = target
        Task.detached(priority: .userInitiated) { [weak self] in
            AirPods.toggle()
            let actual = AirPods.isConnected()
            await MainActor.run { [weak self] in self?.airPodsConnected = actual }
        }
    }

    // MARK: - Do Not Disturb (best-effort UI scripting of Control Center)

    func toggleDoNotDisturb() {
        // macOS exposes no public API for Focus/DND. Drive Control Center via
        // accessibility scripting. Requires Accessibility permission and may need
        // tweaks across macOS versions — this is the one fragile toggle.
        let script = """
        tell application "System Events"
            tell application process "ControlCenter"
                set ccItem to first menu bar item of menu bar 1 whose description contains "Control Center"
                click ccItem
                delay 0.4
                try
                    click (first button of window 1 whose description is "Focus")
                    delay 0.4
                    click (first button of window 1 whose description contains "Do Not Disturb")
                on error
                    key code 53
                end try
                delay 0.2
                key code 53
            end tell
        end tell
        """
        doNotDisturb.toggle()
        Shell.spawn("/usr/bin/osascript", ["-e", script])
    }

    // MARK: - Show File Extensions

    func toggleFileExtensions() {
        let target = !showFileExtensions
        Shell.run("/usr/bin/defaults",
                  ["write", "-g", "AppleShowAllExtensions", "-bool", target ? "true" : "false"])
        Shell.run("/usr/bin/killall", ["Finder"])
        showFileExtensions = target
    }

    nonisolated private func readFileExtensions() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "-g", "AppleShowAllExtensions"])
        return value == "1" || value.lowercased() == "true"
    }

    // MARK: - Dock Auto-hide

    func toggleDockAutohide() {
        let target = !dockAutohide
        Shell.run("/usr/bin/defaults",
                  ["write", "com.apple.dock", "autohide", "-bool", target ? "true" : "false"])
        Shell.run("/usr/bin/killall", ["Dock"])
        dockAutohide = target
    }

    nonisolated private func readDockAutohide() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.dock", "autohide"])
        return value == "1" || value.lowercased() == "true"
    }

    // MARK: - Stage Manager

    func toggleStageManager() {
        let target = !stageManager
        Shell.run("/usr/bin/defaults",
                  ["write", "com.apple.WindowManager", "GloballyEnabled", "-bool", target ? "true" : "false"])
        Shell.run("/usr/bin/killall", ["WindowManager"])
        stageManager = target
    }

    nonisolated private func readStageManager() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.WindowManager", "GloballyEnabled"])
        return value == "1" || value.lowercased() == "true"
    }

    // MARK: - Audio output

    func cycleAudioOutput() {
        AudioOutput.cycle()
        audioDevices = AudioOutput.outputDevices()
        audioOutputID = AudioOutput.currentDeviceID()
    }

    func selectAudioDevice(_ id: AudioDeviceID) {
        AudioOutput.setDevice(id)
        audioOutputID = AudioOutput.currentDeviceID()
    }

    // MARK: - AirDrop visibility (Off / Contacts Only / Everyone)

    static let airDropModes = ["Off", "Contacts Only", "Everyone"]

    func cycleAirDrop() {
        let idx = Self.airDropModes.firstIndex(of: airDropMode) ?? 0
        setAirDrop(Self.airDropModes[(idx + 1) % Self.airDropModes.count])
    }

    func setAirDrop(_ mode: String) {
        Shell.run("/usr/bin/defaults",
                  ["write", "com.apple.sharingd", "DiscoverableMode", "-string", mode])
        Shell.spawn("/usr/bin/killall", ["sharingd"])
        airDropMode = mode
    }

    nonisolated private func readAirDrop() -> String {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.sharingd", "DiscoverableMode"])
        return value.isEmpty ? "Off" : value
    }

    // MARK: - Momentary actions

    func clearClipboard() {
        NSPasteboard.general.clearContents()
    }

    func ejectAllDisks() {
        Shell.osascript("tell application \"Finder\" to eject (every disk whose ejectable is true)")
    }

    func sleepNow() {
        Shell.spawn("/usr/bin/pmset", ["sleepnow"])
    }

    func startScreenSaver() {
        Shell.spawn("/usr/bin/open",
                    ["-a", "/System/Library/CoreServices/ScreenSaverEngine.app"])
    }

    func lockScreen() {
        // Control-Command-Q is the system "Lock Screen" shortcut.
        Shell.osascript(
            "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"
        )
    }

    func sleepDisplay() {
        Shell.spawn("/usr/bin/pmset", ["displaysleepnow"])
    }

    func emptyTrash() {
        Shell.osascript("tell application \"Finder\" to empty trash")
    }
}
