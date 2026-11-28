import SwiftUI

enum SettingsPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case toggles
    case keepAwake
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .toggles: "Toggles"
        case .keepAwake: "Keep Awake"
        case .permissions: "Permissions"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .toggles: "switch.2"
        case .keepAwake: "cup.and.saucer"
        case .permissions: "hand.raised"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var controller: SystemController
    @ObservedObject var panel: TogglePanelModel
    @State private var page: SettingsPage? = .toggles
    @State private var selectedID: ToggleID?

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                ForEach(SettingsPage.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 168, ideal: 188, max: 220)
            .navigationTitle("Toggle")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detail
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
            }
            .navigationTitle(page?.title ?? "Toggle")
        }
        .frame(minWidth: 760, minHeight: 540)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch page ?? .toggles {
        case .general: generalPage
        case .toggles: togglesPage
        case .keepAwake: keepAwakePage
        case .permissions: permissionsPage
        case .about: aboutPage
        }
    }

    private var generalPage: some View {
        SettingsGroup(title: "Updates") {
            settingsRow {
                Text("Updates")
                Spacer(minLength: 8)
                if let status = controller.updateStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Button(controller.isCheckingForUpdates ? "Checking…" : "Check Now") {
                    controller.checkForUpdates()
                }
                .disabled(controller.isCheckingForUpdates)
                Button("Open Releases") {
                    controller.openLatestReleasePage()
                }
            }
        }
    }

    private var togglesPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup(title: "Default view") {
                settingsRow {
                    Text("Default view")
                    Spacer(minLength: 8)
                    Picker("Default view", selection: viewMode) {
                        Text("Grid").tag(PanelViewMode.grid)
                        Text("List").tag(PanelViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                }
            }
            SettingsGroup(title: "Order and visibility") {
                ForEach(panel.state.order) { id in
                    orderRow(id)
                }
                HStack(spacing: 8) {
                    Button("Move Up") { moveSelected(by: -1) }
                        .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                        .disabled(!canMove(-1))
                    Button("Move Down") { moveSelected(by: 1) }
                        .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                        .disabled(!canMove(1))
                    Spacer()
                    Button("Restore Default") {
                        panel.restoreOrderAndVisibility()
                    }
                }
                .padding(10)
            }
            SettingsGroup(title: "Preview") {
                PanelPreview(controller: controller, panel: panel)
                    .padding(8)
            }
        }
    }

    private var keepAwakePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup(title: "Durations in the Keep Awake menu") {
                ForEach(KeepAwakeDuration.allCases) { duration in
                    settingsRow {
                        Toggle(duration.title, isOn: shownBinding(duration.rawValue))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .accessibilityLabel(duration.title)
                        Text(duration.title)
                        Spacer(minLength: 8)
                        if panel.state.keepAwakeMenu.defaultMinutes == duration.rawValue {
                            Text("Default")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        } else {
                            Button("Make default") {
                                makeDefault(duration.rawValue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            SettingsGroup(title: "While Keep Awake is on") {
                settingsRow {
                    Text("Prevent")
                    Spacer(minLength: 8)
                    Picker("Prevent", selection: $controller.keepAwakeMode) {
                        Text("System").tag(KeepAwakeMode.systemSleep)
                        Text("Display").tag(KeepAwakeMode.displaySleep)
                        Text("Both").tag(KeepAwakeMode.both)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                }
            }
        }
    }

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup {
                settingsRow {
                    Text("Accessibility")
                    Spacer(minLength: 8)
                    statusPill(
                        controller.accessibilityGranted ? "Granted" : "Needed",
                        tint: controller.accessibilityGranted ? .green : .orange
                    )
                    Button("Open Settings") { controller.openAccessibilitySettings() }
                        .accessibilityLabel("Open Accessibility Settings")
                }
                settingsRow {
                    Text("Automation")
                    Spacer(minLength: 8)
                    Button("Open Settings") { controller.openAutomationSettings() }
                        .accessibilityLabel("Open Automation Settings")
                }
                settingsRow {
                    Text("Launch at Login")
                    Spacer(minLength: 8)
                    if let status = controller.launchAtLoginStatus {
                        statusPill(status, tint: .orange)
                        Button("Open Settings") { controller.openLoginItemsSettings() }
                            .accessibilityLabel("Open Login Items Settings")
                    }
                    Toggle("Launch at Login", isOn: Binding(
                        get: { controller.launchAtLogin },
                        set: { controller.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                settingsRow {
                    Text("Bluetooth warning")
                    Spacer(minLength: 8)
                    if controller.bluetoothWarningSuppressed {
                        Button("Re-enable") { controller.resetBluetoothWarning() }
                    } else {
                        statusPill("On", tint: .green)
                    }
                }
            }
        }
    }

    private var aboutPage: some View {
        SettingsGroup {
            settingsRow {
                Text("Version")
                Spacer(minLength: 8)
                Text(controller.appVersionLabel)
                    .foregroundStyle(.secondary)
            }
            settingsRow {
                Text("Quit")
                Spacer(minLength: 8)
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
    }

    private func orderRow(_ id: ToggleID) -> some View {
        let visible = panel.state.isVisible(id)
        let available = controller.toggleAvailability.isDisplayed(id)
        return settingsRow {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            ToggleGlyph(symbol: id.symbol(isOn: false), size: 11)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(visible ? AnyShapeStyle(id.activeTint.gradient) : AnyShapeStyle(Color.gray.opacity(0.35))))
                .accessibilityHidden(true)
            Text(id.title)
                .lineLimit(1)
            if id.hasDropdown {
                Text("Dropdown")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            Spacer(minLength: 4)
            Toggle(id.title, isOn: Binding(
                get: { panel.state.isVisible(id) },
                set: { panel.setVisible(id, $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel("Show \(id.title)")
        }
        .opacity(visible && available ? 1 : 0.45)
        .background(selectedID == id ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { selectedID = id })
        .draggable(id.rawValue)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let source = ToggleID(rawValue: raw) else { return false }
            panel.move(source, toIndexOf: id)
            selectedID = source
            return true
        }
        .accessibilityAction(named: "Move up") { panel.moveUp(id) }
        .accessibilityAction(named: "Move down") { panel.moveDown(id) }
    }

    private var viewMode: Binding<PanelViewMode> {
        Binding(
            get: { panel.viewMode },
            set: { panel.viewMode = $0 }
        )
    }

    private func shownBinding(_ minutes: Int) -> Binding<Bool> {
        Binding(
            get: { panel.state.keepAwakeMenu.enabled.contains(minutes) },
            set: { panel.setKeepAwakeShown(minutes, $0) }
        )
    }

    private func makeDefault(_ minutes: Int) {
        panel.setKeepAwakeDefault(minutes)
        controller.defaultKeepAwakeMinutes = panel.state.keepAwakeMenu.defaultMinutes
    }

    private func canMove(_ delta: Int) -> Bool {
        guard let selectedID, let index = panel.state.order.firstIndex(of: selectedID) else { return false }
        return panel.state.order.indices.contains(index + delta)
    }

    private func moveSelected(by delta: Int) {
        guard let selectedID else { return }
        if delta < 0 { panel.moveUp(selectedID) } else { panel.moveDown(selectedID) }
    }

    private func refresh() {
        controller.refreshSettings()
        controller.refresh()
        let minutes = panel.state.keepAwakeMenu.defaultMinutes
        if controller.defaultKeepAwakeMinutes != minutes {
            controller.defaultKeepAwakeMinutes = minutes
        }
        if selectedID == nil { selectedID = panel.state.order.first }
    }

    private func statusPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }
}

private struct SettingsGroup<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                content()
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }
        }
    }
}

private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) {
        HStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
        Divider().padding(.leading, 12)
    }
}

private struct PanelPreview: View {
    @ObservedObject var controller: SystemController
    @ObservedObject var panel: TogglePanelModel

    var body: some View {
        let width: CGFloat = panel.viewMode == .list ? 320 : 340
        ContentView(controller: controller, panel: panel, isInteractive: false)
            .scaleEffect(0.68, anchor: .top)
            .frame(width: width * 0.68, height: 300, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
