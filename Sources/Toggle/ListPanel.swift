import SwiftUI

struct ListPanel: View {
    @ObservedObject var controller: SystemController
    @ObservedObject var panel: TogglePanelModel
    var runs: [ToggleRun]
    var isInteractive: Bool
    var blocked: Bool
    var current: PanelTarget?
    var expandedID: ToggleID?
    var highlight: Int
    var a11yFocus: AccessibilityFocusState<PanelTarget?>.Binding
    var onToggleExpand: (ToggleID) -> Void
    var onPick: (ToggleID, DropdownOption) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AdaptiveGlassContainer(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(runs) { run in
                    sectionCard(run)
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: expandedID)
    }

    private func sectionCard(_ run: ToggleRun) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(run.section.title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            ForEach(run.ids) { id in
                row(id)
            }
        }
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(_ id: ToggleID) -> some View {
        let on = ToggleActions.isOn(id, controller: controller)
        let enabled = controller.toggleAvailability.isEnabled(id)
        let expanded = expandedID == id
        let options = ToggleActions.options(
            for: id,
            controller: controller,
            menuMinutes: panel.state.keepAwakeMenu.menuMinutes
        )
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                icon(id, on: on == true)
                Button {
                    guard isInteractive, enabled, !blocked else { return }
                    if id.hasDropdown {
                        onToggleExpand(id)
                    } else {
                        ToggleActions.trigger(id, controller: controller)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(id.title)
                            .font(.callout.weight(on == true ? .semibold : .regular))
                            .foregroundStyle(.primary)
                        if let subtitle = ToggleActions.subtitle(id, controller: controller) {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isInteractive && (blocked || !enabled))
                .accessibilityLabel(id.title)
                .accessibilityValue(ToggleActions.accessibilityValue(id, controller: controller))
                .accessibilityHint(ToggleActions.accessibilityHint(id))
                if id.hasDropdown {
                    chevron(id, expanded: expanded)
                }
                if let on {
                    Toggle(id.title, isOn: Binding(
                        get: { on },
                        set: { newValue in
                            guard isInteractive, enabled, !blocked, newValue != on else { return }
                            ToggleActions.trigger(id, controller: controller)
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .accessibilityLabel(id.title)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .opacity(enabled ? 1 : 0.4)
            if expanded {
                dropdown(id, options: options)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .help(ToggleActions.help(id, controller: controller))
        .accessibilityElement(children: .contain)
        .accessibilityFocused(a11yFocus, equals: .tile(id))
        .focusRing(current == .tile(id))
        .modifier(OptionsAction(enabled: id.hasDropdown) { onToggleExpand(id) })
    }

    private func icon(_ id: ToggleID, on: Bool) -> some View {
        ToggleGlyph(symbol: id.symbol(isOn: on), size: 13)
            .foregroundStyle(on ? Color.white : Color.primary.opacity(0.8))
            .frame(width: 28, height: 28)
            .adaptiveGlass(tint: on ? id.activeTint : nil, in: Circle())
            .accessibilityHidden(true)
    }

    private func chevron(_ id: ToggleID, expanded: Bool) -> some View {
        Button {
            guard isInteractive, !blocked else { return }
            onToggleExpand(id)
        } label: {
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .rotationEffect(.degrees(expanded ? 180 : 0))
                .frame(width: 28, height: 28)
                .adaptiveGlass(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Options")
        .accessibilityHint("Shows choices for \(id.title)")
    }

    private func dropdown(_ id: ToggleID, options: [DropdownOption]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                if option.isAction, index > 0 {
                    Divider().padding(.horizontal, 8)
                }
                Button {
                    guard isInteractive else { return }
                    onPick(id, option)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .opacity(option.isSelected ? 1 : 0)
                            .accessibilityHidden(true)
                        Text(option.title)
                            .font(.callout)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(minHeight: 28)
                    .background {
                        if index == highlight || option.isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(option.isSelected ? 0.16 : 0.08))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option.isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

private struct OptionsAction: ViewModifier {
    var enabled: Bool
    var action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAction(named: "Options", action)
        } else {
            content
        }
    }
}
