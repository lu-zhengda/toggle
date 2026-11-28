import Foundation

enum PanelViewMode: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case grid
    case list

    var id: String { rawValue }
}

enum ToggleSection: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case connectivity
    case displayAndSound
    case focusAndPower
    case finderAndDock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connectivity: "Connectivity"
        case .displayAndSound: "Display & Sound"
        case .focusAndPower: "Focus & Power"
        case .finderAndDock: "Finder & Dock"
        }
    }
}

enum ToggleID: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case wifi
    case bluetooth
    case airDrop
    case airPods
    case darkMode
    case nightShift
    case trueTone
    case mute
    case keepAwake
    case lowPowerMode
    case doNotDisturb
    case stageManager
    case hideDesktopIcons
    case hiddenFiles
    case fileExtensions
    case dockAutohide

    var id: String { rawValue }

    static let defaultOrder: [ToggleID] = [
        .wifi, .bluetooth, .airDrop, .airPods,
        .darkMode, .nightShift, .trueTone, .mute,
        .keepAwake, .lowPowerMode, .doNotDisturb, .stageManager,
        .hideDesktopIcons, .hiddenFiles, .fileExtensions, .dockAutohide,
    ]

    var section: ToggleSection {
        switch self {
        case .wifi, .bluetooth, .airDrop, .airPods: .connectivity
        case .darkMode, .nightShift, .trueTone, .mute: .displayAndSound
        case .keepAwake, .lowPowerMode, .doNotDisturb, .stageManager: .focusAndPower
        case .hideDesktopIcons, .hiddenFiles, .fileExtensions, .dockAutohide: .finderAndDock
        }
    }

    var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .bluetooth: "Bluetooth"
        case .airDrop: "AirDrop"
        case .airPods: "AirPods"
        case .darkMode: "Dark Mode"
        case .nightShift: "Night Shift"
        case .trueTone: "True Tone"
        case .mute: "Mute"
        case .keepAwake: "Keep Awake"
        case .lowPowerMode: "Low Power Mode"
        case .doNotDisturb: "Do Not Disturb"
        case .stageManager: "Stage Manager"
        case .hideDesktopIcons: "Hide Desktop Icons"
        case .hiddenFiles: "Hidden Files"
        case .fileExtensions: "File Extensions"
        case .dockAutohide: "Dock Auto-hide"
        }
    }

    var gridTitle: String {
        switch self {
        case .lowPowerMode: "Low Power"
        case .hideDesktopIcons: "Desktop Icons"
        case .fileExtensions: "Extensions"
        default: title
        }
    }

    var hasDropdown: Bool {
        switch self {
        case .airDrop, .airPods, .keepAwake, .mute: true
        default: false
        }
    }
}

struct ToggleRun: Equatable, Sendable, Identifiable {
    var section: ToggleSection
    var ids: [ToggleID]

    var id: String {
        section.rawValue + ":" + ids.map(\.rawValue).joined(separator: ",")
    }
}

struct ToggleAvailability: Equatable, Sendable {
    var wifiAvailable: Bool
    var bluetoothAvailable: Bool
    var airPodsAvailable: Bool
    var nightShiftAvailable: Bool
    var trueToneAvailable: Bool
    var lowPowerModeAvailable: Bool

    static let all = ToggleAvailability(
        wifiAvailable: true,
        bluetoothAvailable: true,
        airPodsAvailable: true,
        nightShiftAvailable: true,
        trueToneAvailable: true,
        lowPowerModeAvailable: true
    )

    func isDisplayed(_ id: ToggleID) -> Bool {
        switch id {
        case .bluetooth: bluetoothAvailable
        case .airPods: airPodsAvailable
        case .nightShift: nightShiftAvailable
        case .lowPowerMode: lowPowerModeAvailable
        case .wifi, .airDrop, .darkMode, .trueTone, .mute, .keepAwake, .doNotDisturb,
             .stageManager, .hideDesktopIcons, .hiddenFiles, .fileExtensions, .dockAutohide:
            true
        }
    }

    func isEnabled(_ id: ToggleID) -> Bool {
        switch id {
        case .wifi: wifiAvailable
        case .trueTone: trueToneAvailable
        default: true
        }
    }
}

enum KeepAwakeDuration: Int, CaseIterable, Sendable, Identifiable {
    case fifteen = 15
    case thirty = 30
    case oneHour = 60
    case twoHours = 120
    case fiveHours = 300
    case indefinite = 0

    var id: Int { rawValue }

    static var allMinutes: [Int] { allCases.map(\.rawValue) }

    var title: String {
        switch self {
        case .fifteen: "15 minutes"
        case .thirty: "30 minutes"
        case .oneHour: "1 hour"
        case .twoHours: "2 hours"
        case .fiveHours: "5 hours"
        case .indefinite: "Indefinitely"
        }
    }

    static func normalized(_ minutes: Int) -> Int {
        allMinutes.contains(minutes) ? minutes : Self.indefinite.rawValue
    }

    static func name(for minutes: Int) -> String {
        Self(rawValue: minutes)?.title ?? "\(minutes) minutes"
    }
}

struct KeepAwakeMenuConfiguration: Equatable, Sendable {
    var enabled: Set<Int>
    var defaultMinutes: Int

    static func allEnabled(defaultMinutes: Int) -> KeepAwakeMenuConfiguration {
        let minutes = KeepAwakeDuration.normalized(defaultMinutes)
        return KeepAwakeMenuConfiguration(
            enabled: Set(KeepAwakeDuration.allMinutes),
            defaultMinutes: minutes
        )
    }

    var menuMinutes: [Int] {
        KeepAwakeDuration.allMinutes.filter { enabled.contains($0) || $0 == defaultMinutes }
    }

    func settingShown(_ minutes: Int, _ shown: Bool) -> KeepAwakeMenuConfiguration {
        guard KeepAwakeDuration.allMinutes.contains(minutes) else { return self }
        var copy = self
        if shown {
            copy.enabled.insert(minutes)
        } else if minutes != copy.defaultMinutes, copy.enabled.count > 1 {
            copy.enabled.remove(minutes)
        }
        return copy
    }

    func settingDefault(_ minutes: Int) -> KeepAwakeMenuConfiguration {
        guard KeepAwakeDuration.allMinutes.contains(minutes) else { return self }
        var copy = self
        copy.defaultMinutes = minutes
        copy.enabled.insert(minutes)
        return copy
    }
}

struct TogglePanelState: Equatable, Sendable {
    var viewMode: PanelViewMode
    var order: [ToggleID]
    var hidden: Set<ToggleID>
    var collapsed: Set<ToggleSection>
    var keepAwakeMenu: KeepAwakeMenuConfiguration

    static let standard = TogglePanelState(
        viewMode: .grid,
        order: ToggleID.defaultOrder,
        hidden: [],
        collapsed: [.finderAndDock],
        keepAwakeMenu: .allEnabled(defaultMinutes: 0)
    )

    func isVisible(_ id: ToggleID) -> Bool {
        !hidden.contains(id)
    }

    func displayed(using availability: ToggleAvailability) -> [ToggleID] {
        order.filter { isVisible($0) && availability.isDisplayed($0) }
    }

    func sectionRuns(in ids: [ToggleID]) -> [ToggleRun] {
        var runs: [ToggleRun] = []
        for id in ids {
            if var last = runs.last, last.section == id.section {
                last.ids.append(id)
                runs[runs.count - 1] = last
            } else {
                runs.append(ToggleRun(section: id.section, ids: [id]))
            }
        }
        return runs
    }

    func settingVisible(_ id: ToggleID, _ visible: Bool) -> TogglePanelState {
        var copy = self
        if visible {
            copy.hidden.remove(id)
        } else {
            copy.hidden.insert(id)
        }
        return copy
    }

    func moving(_ id: ToggleID, by delta: Int) -> TogglePanelState {
        guard let index = order.firstIndex(of: id) else { return self }
        let target = index + delta
        guard order.indices.contains(target) else { return self }
        var copy = self
        copy.order.swapAt(index, target)
        return copy
    }

    func moving(_ id: ToggleID, toIndexOf target: ToggleID) -> TogglePanelState {
        guard let from = order.firstIndex(of: id), let to = order.firstIndex(of: target), from != to else {
            return self
        }
        var items = order
        let moved = items.remove(at: from)
        items.insert(moved, at: to)
        var copy = self
        copy.order = items
        return copy
    }

    func moving(from source: IndexSet, to destination: Int) -> TogglePanelState {
        var items = order
        let movingIDs = source.sorted().compactMap { items.indices.contains($0) ? items[$0] : nil }
        for index in source.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }
        let adjusted = destination - source.filter { $0 < destination }.count
        let index = min(max(adjusted, 0), items.count)
        items.insert(contentsOf: movingIDs, at: index)
        var copy = self
        copy.order = items
        return copy
    }

    func togglingCollapsed(_ section: ToggleSection) -> TogglePanelState {
        var copy = self
        if copy.collapsed.contains(section) {
            copy.collapsed.remove(section)
        } else {
            copy.collapsed.insert(section)
        }
        return copy
    }

    func settingKeepAwakeShown(_ minutes: Int, _ shown: Bool) -> TogglePanelState {
        var copy = self
        copy.keepAwakeMenu = keepAwakeMenu.settingShown(minutes, shown)
        return copy
    }

    func settingKeepAwakeDefault(_ minutes: Int) -> TogglePanelState {
        var copy = self
        copy.keepAwakeMenu = keepAwakeMenu.settingDefault(minutes)
        return copy
    }

    func restoredOrderAndVisibility() -> TogglePanelState {
        var copy = self
        copy.order = ToggleID.defaultOrder
        copy.hidden = []
        return copy
    }

    func save(to defaults: UserDefaults) {
        defaults.set(viewMode.rawValue, forKey: Keys.viewMode)
        defaults.set(order.map(\.rawValue), forKey: Keys.order)
        defaults.set(hidden.map(\.rawValue).sorted(), forKey: Keys.hidden)
        defaults.set(collapsed.map(\.rawValue).sorted(), forKey: Keys.collapsed)
        defaults.set(true, forKey: Keys.collapsedStored)
        defaults.set(keepAwakeMenu.enabled.map(String.init).sorted(), forKey: Keys.keepAwakeMinutes)
        defaults.set(true, forKey: Keys.keepAwakeMinutesStored)
        defaults.set(keepAwakeMenu.defaultMinutes, forKey: Keys.keepAwakeDefault)
    }

    static func load(from defaults: UserDefaults) -> TogglePanelState {
        let viewMode = PanelViewMode(rawValue: defaults.string(forKey: Keys.viewMode) ?? "") ?? .grid
        let order = sanitizedOrder(defaults.stringArray(forKey: Keys.order) ?? [])
        let hidden = sanitizedHidden(defaults.stringArray(forKey: Keys.hidden) ?? [])
        let collapsed: Set<ToggleSection>
        if defaults.object(forKey: Keys.collapsedStored) == nil {
            collapsed = [.finderAndDock]
        } else {
            collapsed = sanitizedCollapsed(defaults.stringArray(forKey: Keys.collapsed) ?? [])
        }
        let storedDefault = KeepAwakeDuration.normalized(
            defaults.object(forKey: Keys.keepAwakeDefault) == nil
                ? 0
                : defaults.integer(forKey: Keys.keepAwakeDefault)
        )
        let enabled: Set<Int>
        if defaults.object(forKey: Keys.keepAwakeMinutesStored) == nil {
            enabled = Set(KeepAwakeDuration.allMinutes)
        } else {
            let parsed = Set((defaults.stringArray(forKey: Keys.keepAwakeMinutes) ?? []).compactMap(Int.init))
            let known = parsed.intersection(Set(KeepAwakeDuration.allMinutes))
            enabled = known.isEmpty ? Set(KeepAwakeDuration.allMinutes) : known
        }
        var menu = KeepAwakeMenuConfiguration(enabled: enabled, defaultMinutes: storedDefault)
        menu.enabled.insert(storedDefault)
        return TogglePanelState(
            viewMode: viewMode,
            order: order,
            hidden: hidden,
            collapsed: collapsed,
            keepAwakeMenu: menu
        )
    }

    static func sanitizedOrder(_ raw: [String]) -> [ToggleID] {
        var seen = Set<ToggleID>()
        var order: [ToggleID] = []
        for item in raw {
            guard let id = ToggleID(rawValue: item), seen.insert(id).inserted else { continue }
            order.append(id)
        }
        for id in ToggleID.defaultOrder where seen.insert(id).inserted {
            order.append(id)
        }
        return order
    }

    static func sanitizedHidden(_ raw: [String]) -> Set<ToggleID> {
        Set(raw.compactMap(ToggleID.init(rawValue:)))
    }

    static func sanitizedCollapsed(_ raw: [String]) -> Set<ToggleSection> {
        Set(raw.compactMap(ToggleSection.init(rawValue:)))
    }

    private enum Keys {
        static let viewMode = "panelViewMode"
        static let order = "toggleOrder"
        static let hidden = "toggleHidden"
        static let collapsed = "collapsedToggleSections"
        static let collapsedStored = "collapsedToggleSectionsStored"
        static let keepAwakeMinutes = "keepAwakeMenuMinutes"
        static let keepAwakeMinutesStored = "keepAwakeMenuMinutesStored"
        static let keepAwakeDefault = "defaultKeepAwakeMinutes"
    }
}
