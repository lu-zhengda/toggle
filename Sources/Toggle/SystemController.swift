import Foundation
import SwiftUI
import AppKit
import CoreAudio
import IOKit.pwr_mgt
import ServiceManagement
import ApplicationServices

enum KeepAwakeMode: String, CaseIterable, Identifiable {
    case systemSleep
    case displaySleep
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemSleep: "Prevent system sleep"
        case .displaySleep: "Prevent display sleep"
        case .both: "Prevent both"
        }
    }

    var commandEquivalent: String {
        switch self {
        case .systemSleep: "caffeinate -i"
        case .displaySleep: "caffeinate -d"
        case .both: "caffeinate -i -d"
        }
    }

    var assertionTypes: [String] {
        switch self {
        case .systemSleep:
            [kIOPMAssertionTypePreventUserIdleSystemSleep as String]
        case .displaySleep:
            [kIOPMAssertionTypePreventUserIdleDisplaySleep as String]
        case .both:
            [
                kIOPMAssertionTypePreventUserIdleSystemSleep as String,
                kIOPMAssertionTypePreventUserIdleDisplaySleep as String,
            ]
        }
    }
}

struct ActionFeedback: Equatable, Sendable {
    let message: String
    let symbol: String
    let isError: Bool
}

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
    @Published var showFileExtensions = false
    @Published var dockAutohide = false
    @Published var stageManager = false
    @Published var lowPowerMode = false
    @Published var audioDevices: [AudioDevice] = []
    @Published var audioOutputID: AudioDeviceID = 0
    @Published var airDropMode = "Off"

    // Settings
    @Published var launchAtLogin = false
    @Published var keepAwakeMode: KeepAwakeMode {
        didSet {
            UserDefaults.standard.set(keepAwakeMode.rawValue, forKey: Self.keepAwakeModeKey)
            if keepAwake, oldValue != keepAwakeMode { reconfigureKeepAwake() }
        }
    }
    @Published var defaultKeepAwakeMinutes: Int {
        didSet { UserDefaults.standard.set(defaultKeepAwakeMinutes, forKey: Self.defaultKeepAwakeMinutesKey) }
    }
    @Published var isCheckingForUpdates = false
    @Published var updateStatus: String?
    @Published var latestReleaseURL: URL?
    @Published var bluetoothWarningSuppressed = false
    @Published var launchAtLoginStatus: String?

    // Operation health shown in the compact panel.
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasLoadedState = false
    @Published private(set) var feedback: ActionFeedback?
    @Published private(set) var busyActions: Set<String> = []

    // Availability is refreshed off-main so rendering never touches slow APIs.
    @Published private(set) var trueToneAvailable = false
    @Published private(set) var airPodsAvailable = false
    @Published private(set) var lowPowerModeAvailable = false
    @Published private(set) var wifiAvailable = false
    @Published private(set) var accessibilityGranted = false

    var audioOutputName: String {
        audioDevices.first { $0.id == audioOutputID }?.name ?? "Output"
    }

    // Feature availability (drives whether a tile is shown)
    let nightShiftAvailable = NightShift.isAvailable
    let bluetoothAvailable = BluetoothPower.isAvailable

    private var assertionIDs: [IOPMAssertionID] = []
    private var keepAwakeTimer: DispatchWorkItem?
    private var refreshGeneration = 0
    private var feedbackTask: Task<Void, Never>?

    nonisolated private static let keepAwakeModeKey = "keepAwakeMode"
    nonisolated private static let defaultKeepAwakeMinutesKey = "defaultKeepAwakeMinutes"
    nonisolated private static let suppressBluetoothWarningKey = "suppressBluetoothWarning"
    nonisolated private static let releasesURL = URL(string: "https://github.com/lu-zhengda/toggle/releases")!
    nonisolated private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/lu-zhengda/toggle/releases/latest")!

    init() {
        let storedMode = UserDefaults.standard.string(forKey: Self.keepAwakeModeKey)
        keepAwakeMode = storedMode.flatMap(KeepAwakeMode.init(rawValue:)) ?? .both
        defaultKeepAwakeMinutes = UserDefaults.standard.integer(forKey: Self.defaultKeepAwakeMinutesKey)
        refreshSettings()
    }

    /// Re-read the world so the UI matches reality when the panel opens.
    func refresh() {
        guard !isRefreshing, busyActions.isEmpty else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true

        Task { [weak self] in
            let snapshot = await Self.loadSnapshot()
            guard let self, generation == self.refreshGeneration else { return }
            self.apply(snapshot)
            self.isRefreshing = false
        }
        // Keep Awake reflects this process's own IOPM assertions.
    }

    private struct SystemSnapshot: Sendable {
        let darkMode: Bool
        let desktopIconsVisible: Bool
        let showHiddenFiles: Bool
        let muted: Bool
        let nightShift: Bool
        let trueTone: Bool
        let trueToneAvailable: Bool
        let wifi: Bool
        let wifiAvailable: Bool
        let bluetooth: Bool
        let airPodsConnected: Bool
        let airPodsAvailable: Bool
        let showFileExtensions: Bool
        let dockAutohide: Bool
        let stageManager: Bool
        let lowPowerMode: Bool
        let lowPowerModeAvailable: Bool
        let audioDevices: [AudioDevice]
        let audioOutputID: AudioDeviceID
        let airDropMode: String
        let accessibilityGranted: Bool
    }

    nonisolated private static func loadSnapshot() async -> SystemSnapshot {
        let appearanceTask = Task.detached(priority: .userInitiated) {
            (
                dark: readDarkMode(),
                icons: readDesktopIconsVisible(),
                hidden: readShowHiddenFiles(),
                extensions: readFileExtensions(),
                dock: readDockAutohide(),
                stage: readStageManager()
            )
        }
        let displayTask = Task.detached(priority: .userInitiated) {
            (
                nightShift: NightShift.isEnabled(),
                trueTone: TrueTone.isEnabled(),
                trueToneAvailable: TrueTone.isAvailable
            )
        }
        let connectivityTask = Task.detached(priority: .userInitiated) {
            let wifi = WiFiPower.state()
            let airPods = AirPods.status()
            return (
                wifi: wifi.isOn,
                wifiAvailable: wifi.available,
                bluetooth: BluetoothPower.isOn(),
                airPodsConnected: airPods.isConnected,
                airPodsAvailable: airPods.available,
                airDrop: readAirDrop()
            )
        }
        let powerTask = Task.detached(priority: .utility) {
            (
                lowPower: readLowPowerMode(),
                lowPowerAvailable: lowPowerModeSupported()
            )
        }
        let audioTask = Task.detached(priority: .userInitiated) {
            (
                muted: readMuted(),
                devices: AudioOutput.outputDevices(),
                current: AudioOutput.currentDeviceID()
            )
        }

        let appearance = await appearanceTask.value
        let display = await displayTask.value
        let connectivity = await connectivityTask.value
        let power = await powerTask.value
        let audio = await audioTask.value

        return SystemSnapshot(
            darkMode: appearance.dark,
            desktopIconsVisible: appearance.icons,
            showHiddenFiles: appearance.hidden,
            muted: audio.muted,
            nightShift: display.nightShift,
            trueTone: display.trueTone,
            trueToneAvailable: display.trueToneAvailable,
            wifi: connectivity.wifi,
            wifiAvailable: connectivity.wifiAvailable,
            bluetooth: connectivity.bluetooth,
            airPodsConnected: connectivity.airPodsConnected,
            airPodsAvailable: connectivity.airPodsAvailable,
            showFileExtensions: appearance.extensions,
            dockAutohide: appearance.dock,
            stageManager: appearance.stage,
            lowPowerMode: power.lowPower,
            lowPowerModeAvailable: power.lowPowerAvailable,
            audioDevices: audio.devices,
            audioOutputID: audio.current,
            airDropMode: connectivity.airDrop,
            accessibilityGranted: AXIsProcessTrusted()
        )
    }

    private func apply(_ snapshot: SystemSnapshot) {
        if !busyActions.contains("darkMode") { darkMode = snapshot.darkMode }
        if !busyActions.contains("desktopIcons") { hideDesktopIcons = !snapshot.desktopIconsVisible }
        if !busyActions.contains("hiddenFiles") { showHiddenFiles = snapshot.showHiddenFiles }
        if !busyActions.contains("mute") { muted = snapshot.muted }
        if !busyActions.contains("nightShift") { nightShift = snapshot.nightShift }
        if !busyActions.contains("trueTone") { trueTone = snapshot.trueTone }
        if !busyActions.contains("wifi") { wifi = snapshot.wifi }
        if !busyActions.contains("bluetooth") { bluetooth = snapshot.bluetooth }
        if !busyActions.contains("airPods") { airPodsConnected = snapshot.airPodsConnected }
        if !busyActions.contains("fileExtensions") { showFileExtensions = snapshot.showFileExtensions }
        if !busyActions.contains("dock") { dockAutohide = snapshot.dockAutohide }
        if !busyActions.contains("stageManager") { stageManager = snapshot.stageManager }
        if !busyActions.contains("lowPower") { lowPowerMode = snapshot.lowPowerMode }
        if !busyActions.contains("audio") {
            audioDevices = snapshot.audioDevices
            audioOutputID = snapshot.audioOutputID
        }
        if !busyActions.contains("airDrop") { airDropMode = snapshot.airDropMode }

        trueToneAvailable = snapshot.trueToneAvailable
        wifiAvailable = snapshot.wifiAvailable
        airPodsAvailable = snapshot.airPodsAvailable
        lowPowerModeAvailable = snapshot.lowPowerModeAvailable
        accessibilityGranted = snapshot.accessibilityGranted
        hasLoadedState = true
    }

    // MARK: - Settings

    func refreshSettings() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        switch status {
        case .requiresApproval:
            launchAtLoginStatus = "Approval required in System Settings."
        case .notFound:
            launchAtLoginStatus = "Move Toggle to Applications before enabling this option."
        default:
            launchAtLoginStatus = nil
        }
        bluetoothWarningSuppressed = UserDefaults.standard.bool(forKey: Self.suppressBluetoothWarningKey)
        accessibilityGranted = AXIsProcessTrusted()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshSettings()
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginStatus = error.localizedDescription
        }
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updateStatus = "Checking for updates…"
        latestReleaseURL = nil

        Task {
            do {
                let release = try await Self.fetchLatestRelease()
                let current = Self.appVersion
                latestReleaseURL = release.htmlURL
                if SystemParsing.isVersion(release.version, newerThan: current) {
                    updateStatus = "Update available: \(release.version) (current: \(current))"
                } else {
                    updateStatus = "Toggle is up to date (\(current))."
                }
            } catch {
                latestReleaseURL = Self.releasesURL
                updateStatus = "Couldn’t check for updates. Open GitHub Releases instead."
            }
            isCheckingForUpdates = false
        }
    }

    func openLatestReleasePage() {
        NSWorkspace.shared.open(latestReleaseURL ?? Self.releasesURL)
    }

    func openAccessibilitySettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openAutomationSettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    func openLoginItemsSettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    }

    func resetBluetoothWarning() {
        UserDefaults.standard.removeObject(forKey: Self.suppressBluetoothWarningKey)
        bluetoothWarningSuppressed = false
    }

    var appVersionLabel: String { Self.appVersion }

    private func openSystemSettingsPane(_ urlString: String) {
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    nonisolated private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String)
            ?? (info?["CFBundleVersion"] as? String)
            ?? "Development"
    }

    nonisolated private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
        }

        // The tag is the release's canonical machine-readable version. Human
        // titles may contain unrelated numbers (for example, "2 fixes").
        var version: String { tagName }
    }

    nonisolated private static func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: latestReleaseAPIURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Toggle", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    // MARK: - Action execution and feedback

    nonisolated private static func offMain<Value: Sendable>(
        _ operation: @escaping @Sendable () -> Value
    ) async -> Value {
        await Task.detached(priority: .userInitiated, operation: operation).value
    }

    private func beginAction(_ key: String) -> Bool {
        // Serialize mutations and never overlap them with a snapshot. Besides
        // preventing stale refreshes, this keeps all IOBluetooth work mutually
        // exclusive even though its adapters use separate queues.
        guard !isRefreshing, busyActions.isEmpty else { return false }
        busyActions.insert(key)
        return true
    }

    private func finishAction(
        _ key: String,
        success: Bool,
        successMessage: String,
        failureMessage: String
    ) {
        busyActions.remove(key)
        showFeedback(
            success ? successMessage : failureMessage,
            symbol: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            isError: !success
        )
    }

    private func performBooleanAction(
        key: String,
        title: String,
        target: Bool,
        apply: @escaping @MainActor (Bool) -> Void,
        operation: @escaping @Sendable () async -> Bool,
        read: @escaping @Sendable () -> Bool
    ) {
        guard beginAction(key) else { return }
        apply(target)

        Task { [weak self] in
            let operationSucceeded = await operation()
            let actual = await Self.offMain(read)
            guard let self else { return }
            apply(actual)
            self.finishAction(
                key,
                success: operationSucceeded && actual == target,
                successMessage: "\(title) is \(actual ? "on" : "off").",
                failureMessage: "Couldn’t change \(title)."
            )
        }
    }

    private func showFeedback(_ message: String, symbol: String, isError: Bool = false) {
        // Do not let a later success erase an error before the user can read it.
        if !isError, feedback?.isError == true { return }
        let value = ActionFeedback(message: message, symbol: symbol, isError: isError)
        feedback = value
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: isError
                    ? NSAccessibilityPriorityLevel.high.rawValue
                    : NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: isError ? 5_000_000_000 : 3_000_000_000)
            guard !Task.isCancelled, let self, self.feedback == value else { return }
            self.feedback = nil
        }
    }

    // MARK: - Dark Mode

    func toggleDarkMode() {
        let target = !darkMode
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(target)"
        performBooleanAction(
            key: "darkMode",
            title: "Dark Mode",
            target: target,
            apply: { [weak self] in self?.darkMode = $0 },
            operation: { await Shell.execute("/usr/bin/osascript", ["-e", script]).success },
            read: { Self.readDarkMode() }
        )
    }

    nonisolated private static func readDarkMode() -> Bool {
        Shell.run("/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"])
            .lowercased() == "dark"
    }

    // MARK: - Hide Desktop Icons

    func toggleHideDesktopIcons() {
        let hide = !hideDesktopIcons // hide == don't create desktop
        performBooleanAction(
            key: "desktopIcons",
            title: "Hide Desktop Icons",
            target: hide,
            apply: { [weak self] in self?.hideDesktopIcons = $0 },
            operation: {
                let result = await Shell.execute(
                    "/usr/bin/defaults",
                    ["write", "com.apple.finder", "CreateDesktop", "-bool", hide ? "false" : "true"]
                )
                guard result.success else { return false }
                return await Shell.execute("/usr/bin/killall", ["Finder"], timeout: 5).success
            },
            read: { !Self.readDesktopIconsVisible() }
        )
    }

    nonisolated private static func readDesktopIconsVisible() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.finder", "CreateDesktop"])
        return SystemParsing.bool(fromDefaultsOutput: value, default: true)
    }

    // MARK: - Show Hidden Files

    func toggleHiddenFiles() {
        let show = !showHiddenFiles
        performBooleanAction(
            key: "hiddenFiles",
            title: "Show Hidden Files",
            target: show,
            apply: { [weak self] in self?.showHiddenFiles = $0 },
            operation: {
                let result = await Shell.execute(
                    "/usr/bin/defaults",
                    ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", show ? "true" : "false"]
                )
                guard result.success else { return false }
                return await Shell.execute("/usr/bin/killall", ["Finder"], timeout: 5).success
            },
            read: { Self.readShowHiddenFiles() }
        )
    }

    nonisolated private static func readShowHiddenFiles() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.finder", "AppleShowAllFiles"])
        return SystemParsing.bool(fromDefaultsOutput: value)
    }

    // MARK: - Keep Awake (caffeinate via IOKit power assertion)

    /// Toggle indefinitely, or pass `minutes` to auto-release after a timer.
    func setKeepAwake(_ on: Bool, minutes: Int? = nil) {
        let until = minutes.flatMap { $0 > 0 ? Date().addingTimeInterval(Double($0) * 60) : nil }
        configureKeepAwake(on, until: until)
        let succeeded = keepAwake == on
        let onMessage = minutes.flatMap { $0 > 0 ? "Keep Awake is on for \($0) minutes." : nil }
            ?? "Keep Awake is on."
        showFeedback(
            succeeded ? (on ? onMessage : "Keep Awake is off.") : "Couldn’t change Keep Awake.",
            symbol: succeeded
                ? (on ? "cup.and.saucer.fill" : "checkmark.circle.fill")
                : "exclamationmark.triangle.fill",
            isError: !succeeded
        )
    }

    private func configureKeepAwake(_ on: Bool, until: Date?) {
        keepAwakeTimer?.cancel()
        keepAwakeTimer = nil
        for id in assertionIDs { IOPMAssertionRelease(id) }
        assertionIDs = []
        keepAwakeUntil = nil
        keepAwake = false
        guard on else { return }

        // Matches the user's Settings choice: caffeinate -i, -d, or -i -d.
        for type in keepAwakeMode.assertionTypes {
            var assertionID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Toggle: Keep Awake (\(keepAwakeMode.commandEquivalent))" as CFString,
                &assertionID
            )
            if result == kIOReturnSuccess { assertionIDs.append(assertionID) }
        }
        guard !assertionIDs.isEmpty else { return }
        keepAwake = true

        if let until {
            keepAwakeUntil = until
            let work = DispatchWorkItem { [weak self] in self?.setKeepAwake(false) }
            keepAwakeTimer = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + max(0, until.timeIntervalSinceNow),
                execute: work
            )
        }
    }

    private func reconfigureKeepAwake() {
        let until = keepAwakeUntil
        configureKeepAwake(true, until: until)
        showFeedback(
            keepAwake
                ? "Keep Awake now uses \(keepAwakeMode.title.lowercased())."
                : "Couldn’t update the Keep Awake assertion.",
            symbol: keepAwake ? "cup.and.saucer.fill" : "exclamationmark.triangle.fill",
            isError: !keepAwake
        )
    }

    func toggleKeepAwake() {
        setKeepAwake(!keepAwake, minutes: keepAwake ? nil : defaultKeepAwakeMinutes)
    }

    // MARK: - Mute

    func toggleMute() {
        let target = !muted
        performBooleanAction(
            key: "mute",
            title: "Mute",
            target: target,
            apply: { [weak self] in self?.muted = $0 },
            operation: {
                await Shell.execute(
                    "/usr/bin/osascript",
                    ["-e", "set volume output muted \(target)"]
                ).success
            },
            read: { Self.readMuted() }
        )
    }

    nonisolated private static func readMuted() -> Bool {
        Shell.osascript("output muted of (get volume settings)").lowercased() == "true"
    }

    // MARK: - Night Shift

    func toggleNightShift() {
        let target = !nightShift
        performBooleanAction(
            key: "nightShift",
            title: "Night Shift",
            target: target,
            apply: { [weak self] in self?.nightShift = $0 },
            operation: { await Self.offMain { NightShift.setEnabled(target) } },
            read: { NightShift.isEnabled() }
        )
    }

    // MARK: - True Tone

    func toggleTrueTone() {
        let target = !trueTone
        performBooleanAction(
            key: "trueTone",
            title: "True Tone",
            target: target,
            apply: { [weak self] in self?.trueTone = $0 },
            operation: { await Self.offMain { TrueTone.setEnabled(target) } },
            read: { TrueTone.isEnabled() }
        )
    }

    // MARK: - Wi-Fi

    func toggleWifi() {
        guard wifiAvailable else {
            showFeedback("No Wi-Fi interface is available.", symbol: "wifi.exclamationmark", isError: true)
            return
        }
        let target = !wifi
        performBooleanAction(
            key: "wifi",
            title: "Wi-Fi",
            target: target,
            apply: { [weak self] in self?.wifi = $0 },
            operation: { await Self.offMain { WiFiPower.set(target) } },
            read: { WiFiPower.state().isOn }
        )
    }

    // MARK: - Bluetooth

    func toggleBluetooth() {
        let target = !bluetooth
        guard beginAction("bluetooth") else { return }

        if !target, !UserDefaults.standard.bool(forKey: Self.suppressBluetoothWarningKey) {
            Task { [weak self] in
                let summary = await Self.offMain { BluetoothPower.connectedDeviceSummary() }
                guard let self else { return }
                guard self.confirmBluetoothOff(summary) else {
                    self.busyActions.remove("bluetooth")
                    return
                }
                self.performBluetoothChange(target)
            }
        } else {
            performBluetoothChange(target)
        }
    }

    private func performBluetoothChange(_ target: Bool) {
        bluetooth = target
        Task { [weak self] in
            let operationSucceeded = await Self.offMain { BluetoothPower.set(target) }
            let actual = await Self.offMain { BluetoothPower.isOn() }
            guard let self else { return }
            self.bluetooth = actual
            self.finishAction(
                "bluetooth",
                success: operationSucceeded && actual == target,
                successMessage: "Bluetooth is \(actual ? "on" : "off").",
                failureMessage: "Couldn’t change Bluetooth."
            )
        }
    }

    private func confirmBluetoothOff(_ summary: BluetoothConnectionSummary) -> Bool {
        let names = summary.names
        if names.isEmpty { return true } // nothing to lose

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Turn off Bluetooth?"
        var info = "This will disconnect \(names.count) connected "
            + "device\(names.count == 1 ? "" : "s"): \(names.joined(separator: ", "))."
        if summary.hasInputDevice {
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
        let confirmed = response == .alertSecondButtonReturn
        if confirmed, alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: Self.suppressBluetoothWarningKey)
            bluetoothWarningSuppressed = true
        }
        return confirmed
    }

    // MARK: - AirPods quick-connect

    func toggleAirPods() {
        guard beginAction("airPods") else { return }
        let target = !airPodsConnected
        airPodsConnected = target
        Task { [weak self] in
            let operationSucceeded = await Self.offMain { AirPods.setConnected(target) }
            let actual = await Self.offMain { AirPods.isConnected() }
            guard let self else { return }
            self.airPodsConnected = actual
            self.finishAction(
                "airPods",
                success: operationSucceeded && actual == target,
                successMessage: "AirPods \(actual ? "connected" : "disconnected").",
                failureMessage: "Couldn’t \(target ? "connect" : "disconnect") AirPods."
            )
        }
    }

    // MARK: - Do Not Disturb (best-effort UI scripting of Control Center)

    func toggleDoNotDisturb() {
        guard AXIsProcessTrusted() else {
            accessibilityGranted = false
            showFeedback(
                "Accessibility access is required for Do Not Disturb.",
                symbol: "hand.raised.fill",
                isError: true
            )
            openAccessibilitySettings()
            return
        }
        accessibilityGranted = true
        guard beginAction("doNotDisturb") else { return }

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
                on error errorMessage number errorNumber
                    key code 53
                    error errorMessage number errorNumber
                end try
                delay 0.2
                key code 53
            end tell
        end tell
        """
        Task { [weak self] in
            let result = await Shell.execute("/usr/bin/osascript", ["-e", script])
            guard let self else { return }
            self.finishAction(
                "doNotDisturb",
                success: result.success,
                successMessage: "Do Not Disturb toggled.",
                failureMessage: "Couldn’t toggle Do Not Disturb. Control Center may have changed."
            )
        }
    }

    // MARK: - Show File Extensions

    func toggleFileExtensions() {
        let target = !showFileExtensions
        performBooleanAction(
            key: "fileExtensions",
            title: "Show File Extensions",
            target: target,
            apply: { [weak self] in self?.showFileExtensions = $0 },
            operation: {
                let result = await Shell.execute(
                    "/usr/bin/defaults",
                    ["write", "-g", "AppleShowAllExtensions", "-bool", target ? "true" : "false"]
                )
                guard result.success else { return false }
                return await Shell.execute("/usr/bin/killall", ["Finder"], timeout: 5).success
            },
            read: { Self.readFileExtensions() }
        )
    }

    nonisolated private static func readFileExtensions() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "-g", "AppleShowAllExtensions"])
        return SystemParsing.bool(fromDefaultsOutput: value)
    }

    // MARK: - Dock Auto-hide

    func toggleDockAutohide() {
        let target = !dockAutohide
        performBooleanAction(
            key: "dock",
            title: "Dock Auto-hide",
            target: target,
            apply: { [weak self] in self?.dockAutohide = $0 },
            operation: {
                let result = await Shell.execute(
                    "/usr/bin/defaults",
                    ["write", "com.apple.dock", "autohide", "-bool", target ? "true" : "false"]
                )
                guard result.success else { return false }
                return await Shell.execute("/usr/bin/killall", ["Dock"], timeout: 5).success
            },
            read: { Self.readDockAutohide() }
        )
    }

    nonisolated private static func readDockAutohide() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.dock", "autohide"])
        return SystemParsing.bool(fromDefaultsOutput: value)
    }

    // MARK: - Stage Manager

    func toggleStageManager() {
        let target = !stageManager
        performBooleanAction(
            key: "stageManager",
            title: "Stage Manager",
            target: target,
            apply: { [weak self] in self?.stageManager = $0 },
            operation: {
                let result = await Shell.execute(
                    "/usr/bin/defaults",
                    ["write", "com.apple.WindowManager", "GloballyEnabled", "-bool", target ? "true" : "false"]
                )
                guard result.success else { return false }
                return await Shell.execute("/usr/bin/killall", ["WindowManager"], timeout: 5).success
            },
            read: { Self.readStageManager() }
        )
    }

    nonisolated private static func readStageManager() -> Bool {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.WindowManager", "GloballyEnabled"])
        return SystemParsing.bool(fromDefaultsOutput: value)
    }

    // MARK: - Low Power Mode

    func toggleLowPowerMode() {
        let target = !lowPowerMode
        NSApp.activate(ignoringOtherApps: true)
        performBooleanAction(
            key: "lowPower",
            title: "Low Power Mode",
            target: target,
            apply: { [weak self] in self?.lowPowerMode = $0 },
            operation: {
                let value = target ? "1" : "0"
                return await Shell.execute(
                    "/usr/bin/osascript",
                    ["-e", "do shell script \"/usr/bin/pmset -a lowpowermode \(value)\" with administrator privileges"],
                    timeout: 120
                ).success
            },
            read: { Self.readLowPowerMode() }
        )
    }

    nonisolated private static func readLowPowerMode() -> Bool {
        // Current on/off comes from the live view (reflects the active power source).
        SystemParsing.lowPowerModeValue(in: Shell.run("/usr/bin/pmset", ["-g"])) == true
    }

    // Availability: the live view (`pmset -g`) omits `lowpowermode` on some Macs /
    // macOS versions even when it's supported, so fall back to the per-source
    // profiles (`pmset -g custom`) before deciding the machine can't do it.
    nonisolated private static func lowPowerModeSupported() -> Bool {
        if SystemParsing.lowPowerModeValue(in: Shell.run("/usr/bin/pmset", ["-g"])) != nil {
            return true
        }
        return SystemParsing.lowPowerModeValue(
            in: Shell.run("/usr/bin/pmset", ["-g", "custom"])
        ) != nil
    }

    // MARK: - Audio output

    func cycleAudioOutput() {
        guard beginAction("audio") else { return }
        Task { [weak self] in
            let outcome = await Self.offMain {
                let devices = AudioOutput.outputDevices()
                guard devices.count > 1 else {
                    return (success: false, devices: devices, current: AudioOutput.currentDeviceID())
                }
                let success = AudioOutput.cycle()
                return (success, AudioOutput.outputDevices(), AudioOutput.currentDeviceID())
            }
            guard let self else { return }
            self.audioDevices = outcome.devices
            self.audioOutputID = outcome.current
            self.finishAction(
                "audio",
                success: outcome.success,
                successMessage: "Audio output: \(self.audioOutputName).",
                failureMessage: outcome.devices.count > 1
                    ? "Couldn’t switch audio output."
                    : "No other audio output is available."
            )
        }
    }

    func selectAudioDevice(_ id: AudioDeviceID) {
        guard beginAction("audio") else { return }
        Task { [weak self] in
            let outcome = await Self.offMain {
                let success = AudioOutput.setDevice(id)
                return (success, AudioOutput.outputDevices(), AudioOutput.currentDeviceID())
            }
            guard let self else { return }
            self.audioDevices = outcome.1
            self.audioOutputID = outcome.2
            self.finishAction(
                "audio",
                success: outcome.0 && outcome.2 == id,
                successMessage: "Audio output: \(self.audioOutputName).",
                failureMessage: "Couldn’t switch audio output."
            )
        }
    }

    // MARK: - AirDrop visibility (Off / Contacts Only / Everyone)

    nonisolated static let airDropModes = ["Off", "Contacts Only", "Everyone"]

    func cycleAirDrop() {
        let idx = Self.airDropModes.firstIndex(of: airDropMode) ?? 0
        setAirDrop(Self.airDropModes[(idx + 1) % Self.airDropModes.count])
    }

    func setAirDrop(_ mode: String) {
        guard Self.airDropModes.contains(mode), beginAction("airDrop") else { return }
        let previous = airDropMode
        airDropMode = mode
        Task { [weak self] in
            let result = await Shell.execute(
                "/usr/bin/defaults",
                ["write", "com.apple.sharingd", "DiscoverableMode", "-string", mode]
            )
            var reloadSucceeded = false
            if result.success {
                reloadSucceeded = await Shell.execute(
                    "/usr/bin/killall",
                    ["sharingd"],
                    timeout: 5
                ).success
            }
            let actual = await Self.offMain { Self.readAirDrop() }
            guard let self else { return }
            self.airDropMode = result.success ? actual : previous
            self.finishAction(
                "airDrop",
                success: reloadSucceeded && actual == mode,
                successMessage: "AirDrop: \(actual).",
                failureMessage: "Couldn’t change AirDrop visibility."
            )
        }
    }

    nonisolated private static func readAirDrop() -> String {
        let value = Shell.run("/usr/bin/defaults", ["read", "com.apple.sharingd", "DiscoverableMode"])
        return Self.airDropModes.contains(value) ? value : "Off"
    }

    // MARK: - Momentary actions

    func clearClipboard() {
        NSPasteboard.general.clearContents()
        showFeedback("Clipboard cleared.", symbol: "clipboard.fill")
    }

    func ejectAllDisks() {
        guard beginAction("eject") else { return }
        Task { [weak self] in
            let result = await Shell.execute(
                "/usr/bin/osascript",
                ["-e", "tell application \"Finder\" to eject (every disk whose ejectable is true)"]
            )
            guard let self else { return }
            self.finishAction(
                "eject",
                success: result.success,
                successMessage: "Ejectable disks were ejected.",
                failureMessage: "One or more disks couldn’t be ejected."
            )
        }
    }

    func sleepNow() {
        Shell.spawn("/usr/bin/pmset", ["sleepnow"])
    }

    func startScreenSaver() {
        Shell.spawn("/usr/bin/open",
                    ["-a", "/System/Library/CoreServices/ScreenSaverEngine.app"])
    }

    func lockScreen() {
        guard AXIsProcessTrusted() else {
            accessibilityGranted = false
            showFeedback(
                "Accessibility access is required to lock the screen.",
                symbol: "hand.raised.fill",
                isError: true
            )
            openAccessibilitySettings()
            return
        }
        accessibilityGranted = true
        guard beginAction("lockScreen") else { return }
        // Control-Command-Q is the system "Lock Screen" shortcut.
        Task { [weak self] in
            let result = await Shell.execute(
                "/usr/bin/osascript",
                ["-e", "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"]
            )
            guard let self else { return }
            self.finishAction(
                "lockScreen",
                success: result.success,
                successMessage: "Screen locked.",
                failureMessage: "Couldn’t lock the screen."
            )
        }
    }

    func sleepDisplay() {
        Shell.spawn("/usr/bin/pmset", ["displaysleepnow"])
    }

    func emptyTrash() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Empty the Trash?"
        alert.informativeText = "This permanently deletes every item in the Trash and cannot be undone."
        alert.addButton(withTitle: "Cancel")
        let emptyButton = alert.addButton(withTitle: "Empty Trash")
        emptyButton.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn, beginAction("emptyTrash") else { return }

        Task { [weak self] in
            let result = await Shell.execute(
                "/usr/bin/osascript",
                ["-e", "tell application \"Finder\" to empty trash"],
                timeout: 300
            )
            guard let self else { return }
            self.finishAction(
                "emptyTrash",
                success: result.success,
                successMessage: "Trash emptied.",
                failureMessage: "Couldn’t empty the Trash."
            )
        }
    }
}
