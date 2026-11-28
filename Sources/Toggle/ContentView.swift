import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: SystemController
    @ObservedObject var panel: TogglePanelModel
    var isInteractive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var modeNamespace
    @FocusState private var panelFocused: Bool
    @AccessibilityFocusState private var a11yFocus: PanelTarget?
    @State private var current: PanelTarget?
    @State private var expandedID: ToggleID?
    @State private var highlight = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            FittingScroll(maxHeight: 520) {
                Group {
                    if panel.viewMode == .grid {
                        GridPanel(
                            controller: controller,
                            panel: panel,
                            runs: runs,
                            isInteractive: isInteractive,
                            blocked: controlsBlocked,
                            current: current,
                            a11yFocus: $a11yFocus
                        )
                    } else {
                        ListPanel(
                            controller: controller,
                            panel: panel,
                            runs: runs,
                            isInteractive: isInteractive,
                            blocked: controlsBlocked,
                            current: current,
                            expandedID: expandedID,
                            highlight: highlight,
                            a11yFocus: $a11yFocus,
                            onToggleExpand: toggleExpanded,
                            onPick: pick
                        )
                    }
                }
            }
            QuickActionStrip(
                controller: controller,
                isInteractive: isInteractive,
                blocked: controlsBlocked,
                current: current,
                a11yFocus: $a11yFocus
            )
            if showsStatus {
                status
            }
        }
        .padding(12)
        .frame(width: panel.viewMode == .list ? 320 : 340)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .focusable(isInteractive)
        .focused($panelFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            handle(press)
        }
        .onAppear {
            guard isInteractive else { return }
            controller.refresh()
            panelFocused = true
        }
        .onChange(of: panel.viewMode) { _, _ in
            expandedID = nil
        }
        .onChange(of: a11yFocus) { _, newValue in
            if let newValue { current = newValue }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Toggle")
                .font(.callout.weight(.semibold))
            Spacer(minLength: 0)
            viewSwitch
            GlassCircleButton(
                systemName: "arrow.clockwise",
                help: "Refresh",
                disabled: !isInteractive || controller.isRefreshing
            ) {
                controller.refresh()
            }
            SettingsLink {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .modifier(GlassCircleButtonStyle())
            .help("Settings")
            .accessibilityLabel("Settings")
            .disabled(!isInteractive)
        }
    }

    private var viewSwitch: some View {
        HStack(spacing: 0) {
            modeButton(.grid, symbol: "square.grid.2x2", key: "1")
            modeButton(.list, symbol: "list.bullet", key: "2")
        }
        .padding(2)
        .adaptiveGlass(in: Capsule())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: panel.viewMode)
    }

    private func modeButton(_ mode: PanelViewMode, symbol: String, key: KeyEquivalent) -> some View {
        let title = mode == .grid ? "Grid" : "List"
        return Button {
            panel.viewMode = mode
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 22)
                .background {
                    if panel.viewMode == mode {
                        Capsule()
                            .fill(Color.accentColor.opacity(reduceTransparency ? 0.35 : 0.22))
                            .matchedGeometryEffect(id: "panel-mode", in: modeNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(panel.viewMode == mode ? .isSelected : [])
        .modifier(CommandShortcut(enabled: isInteractive, key: key))
    }

    private var status: some View {
        HStack(spacing: 6) {
            if controller.isRefreshing {
                ProgressView().controlSize(.small)
                Text("Refreshing…")
            } else if !controller.busyActions.isEmpty {
                ProgressView().controlSize(.small)
                Text("Applying…")
            } else if let feedback = controller.feedback {
                Image(systemName: feedback.symbol)
                    .accessibilityHidden(true)
                Text(feedback.message)
                    .lineLimit(1)
                    .foregroundStyle(feedback.isError ? Color.red : Color.secondary)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var showsStatus: Bool {
        controller.isRefreshing || !controller.busyActions.isEmpty || controller.feedback != nil
    }

    private var controlsBlocked: Bool {
        !controller.hasLoadedState || controller.isRefreshing || !controller.busyActions.isEmpty
    }

    private var displayedIDs: [ToggleID] {
        panel.state.displayed(using: controller.toggleAvailability)
    }

    private var runs: [ToggleRun] {
        panel.state.sectionRuns(in: displayedIDs)
    }

    private var focusMap: PanelFocusMap {
        if panel.viewMode == .grid {
            return .grid(runs: runs, collapsed: panel.state.collapsed)
        }
        return .list(ids: displayedIDs)
    }

    private var expandedOptions: [DropdownOption] {
        guard let expandedID else { return [] }
        return ToggleActions.options(
            for: expandedID,
            controller: controller,
            menuMinutes: panel.state.keepAwakeMenu.menuMinutes
        )
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard isInteractive else { return .ignored }
        switch press.key {
        case .upArrow:
            if expandedID != nil {
                highlight = MenuKeyboard.highlight(current: highlight, count: expandedOptions.count, delta: -1)
            } else {
                move(.up)
            }
            return .handled
        case .downArrow:
            if expandedID != nil {
                highlight = MenuKeyboard.highlight(current: highlight, count: expandedOptions.count, delta: 1)
            } else {
                move(.down)
            }
            return .handled
        case .leftArrow:
            if expandedID != nil {
                expandedID = nil
                return .handled
            }
            guard panel.viewMode == .grid else { return .ignored }
            move(.left)
            return .handled
        case .rightArrow:
            if panel.viewMode == .list, expandedID == nil, let id = focusedTile, id.hasDropdown {
                open(id)
                return .handled
            }
            guard panel.viewMode == .grid else { return .ignored }
            move(.right)
            return .handled
        case .escape:
            guard expandedID != nil else { return .ignored }
            expandedID = nil
            return .handled
        case .return:
            if expandedID != nil {
                confirmHighlight()
                return .handled
            }
            if panel.viewMode == .list, let id = focusedTile, id.hasDropdown {
                open(id)
                return .handled
            }
            activateFocused()
            return .handled
        case .space:
            guard expandedID == nil else { return .ignored }
            activateFocused()
            return .handled
        default:
            return .ignored
        }
    }

    private var focusedTile: ToggleID? {
        if case .tile(let id) = current { return id }
        return nil
    }

    private func move(_ direction: FocusDirection) {
        current = focusMap.moved(current, direction: direction)
        a11yFocus = current
    }

    private func open(_ id: ToggleID) {
        let options = ToggleActions.options(
            for: id,
            controller: controller,
            menuMinutes: panel.state.keepAwakeMenu.menuMinutes
        )
        guard !options.isEmpty else { return }
        expandedID = id
        current = .tile(id)
        highlight = options.firstIndex { $0.isSelected } ?? 0
        a11yFocus = .tile(id)
    }

    private func toggleExpanded(_ id: ToggleID) {
        if expandedID == id {
            expandedID = nil
        } else {
            open(id)
        }
    }

    private func confirmHighlight() {
        guard let expandedID, expandedOptions.indices.contains(highlight) else { return }
        pick(expandedID, expandedOptions[highlight])
    }

    private func pick(_ id: ToggleID, _ option: DropdownOption) {
        ToggleActions.apply(option, for: id, controller: controller)
        expandedID = nil
        current = .tile(id)
        a11yFocus = .tile(id)
    }

    private func activateFocused() {
        switch current {
        case .section(let section):
            panel.toggleCollapsed(section)
        case .tile(let id):
            guard controller.toggleAvailability.isEnabled(id), !controlsBlocked else { return }
            ToggleActions.trigger(id, controller: controller)
        case .action(let action):
            guard !controlsBlocked else { return }
            ToggleActions.perform(action, controller: controller)
        case nil:
            current = focusMap.moved(nil, direction: .down)
            a11yFocus = current
        }
    }
}

private struct CommandShortcut: ViewModifier {
    var enabled: Bool
    var key: KeyEquivalent

    func body(content: Content) -> some View {
        if enabled {
            content.keyboardShortcut(key, modifiers: .command)
        } else {
            content
        }
    }
}

private struct FittingScroll<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 1

    var body: some View {
        ScrollView {
            content()
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = max($0, 1) }
        .frame(height: min(contentHeight, maxHeight))
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct QuickActionStrip: View {
    @ObservedObject var controller: SystemController
    var isInteractive: Bool
    var blocked: Bool
    var current: PanelTarget?
    var a11yFocus: AccessibilityFocusState<PanelTarget?>.Binding

    var body: some View {
        HStack(spacing: 4) {
            ForEach(QuickAction.allCases, id: \.self) { action in
                if action == .more {
                    moreMenu
                } else {
                    actionButton(action)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .adaptiveGlass(in: Capsule())
    }

    private func actionButton(_ action: QuickAction) -> some View {
        Button {
            guard isInteractive, !blocked else { return }
            ToggleActions.perform(action, controller: controller)
        } label: {
            actionLabel(action)
        }
        .buttonStyle(.plain)
        .disabled(isInteractive && blocked)
        .help(action.title)
        .accessibilityLabel(action.title)
        .accessibilityFocused(a11yFocus, equals: .action(action))
        .focusRing(current == .action(action))
    }

    private func actionLabel(_ action: QuickAction) -> some View {
        VStack(spacing: 1) {
            Image(systemName: action.systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(action.title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 28)
        .contentShape(Rectangle())
    }

    private var moreMenu: some View {
        Menu {
            Button {
                controller.sleepNow()
            } label: {
                Label("Sleep Now", systemImage: "bed.double.fill")
            }
            Button {
                controller.clearClipboard()
            } label: {
                Label("Clear Clipboard", systemImage: "clipboard.fill")
            }
            Button {
                controller.ejectAllDisks()
            } label: {
                Label("Eject All Disks", systemImage: "eject.fill")
            }
            Button(role: .destructive) {
                controller.emptyTrash()
            } label: {
                Label("Empty Trash", systemImage: "trash.fill")
            }
            Divider()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Toggle", systemImage: "power")
            }
        } label: {
            actionLabel(.more)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(isInteractive && blocked)
        .help("More")
        .accessibilityLabel("More")
        .accessibilityHint("Opens sleep, clipboard, disk, trash, and quit")
        .accessibilityFocused(a11yFocus, equals: .action(.more))
        .focusRing(current == .action(.more))
    }
}
