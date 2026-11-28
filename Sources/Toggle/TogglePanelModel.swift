import Combine
import Foundation

/// Persisted panel layout: view mode, toggle order, visibility, section collapse,
/// and which Keep Awake durations appear in the menu.
@MainActor
final class TogglePanelModel: ObservableObject {
    @Published private(set) var state: TogglePanelState
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = TogglePanelState.load(from: defaults)
    }

    var viewMode: PanelViewMode {
        get { state.viewMode }
        set { commit { $0.viewMode = newValue } }
    }

    func setVisible(_ id: ToggleID, _ visible: Bool) {
        state = state.settingVisible(id, visible)
        state.save(to: defaults)
    }

    func moveUp(_ id: ToggleID) {
        state = state.moving(id, by: -1)
        state.save(to: defaults)
    }

    func moveDown(_ id: ToggleID) {
        state = state.moving(id, by: 1)
        state.save(to: defaults)
    }

    func move(_ id: ToggleID, toIndexOf target: ToggleID) {
        state = state.moving(id, toIndexOf: target)
        state.save(to: defaults)
    }

    func move(from source: IndexSet, to destination: Int) {
        state = state.moving(from: source, to: destination)
        state.save(to: defaults)
    }

    func toggleCollapsed(_ section: ToggleSection) {
        state = state.togglingCollapsed(section)
        state.save(to: defaults)
    }

    func setKeepAwakeShown(_ minutes: Int, _ shown: Bool) {
        state = state.settingKeepAwakeShown(minutes, shown)
        state.save(to: defaults)
    }

    func setKeepAwakeDefault(_ minutes: Int) {
        state = state.settingKeepAwakeDefault(minutes)
        state.save(to: defaults)
    }

    func restoreOrderAndVisibility() {
        state = state.restoredOrderAndVisibility()
        state.save(to: defaults)
    }

    private func commit(_ body: (inout TogglePanelState) -> Void) {
        var copy = state
        body(&copy)
        state = copy
        state.save(to: defaults)
    }
}
