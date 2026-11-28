import SwiftUI

struct GridPanel: View {
    @ObservedObject var controller: SystemController
    @ObservedObject var panel: TogglePanelModel
    var runs: [ToggleRun]
    var isInteractive: Bool
    var blocked: Bool
    var current: PanelTarget?
    var a11yFocus: AccessibilityFocusState<PanelTarget?>.Binding

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        AdaptiveGlassContainer(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(runs) { run in
                    sectionCard(run)
                }
            }
        }
    }

    private func sectionCard(_ run: ToggleRun) -> some View {
        let collapsed = panel.state.collapsed.contains(run.section)
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader(run, collapsed: collapsed)
            if !collapsed {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4),
                    spacing: 4
                ) {
                    ForEach(run.ids) { id in
                        tile(id)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionHeader(_ run: ToggleRun, collapsed: Bool) -> some View {
        Button {
            guard isInteractive else { return }
            panel.toggleCollapsed(run.section)
        } label: {
            HStack(spacing: 8) {
                Text(run.section.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if collapsed {
                    HStack(spacing: 8) {
                        ForEach(run.ids) { id in
                            let on = ToggleActions.isOn(id, controller: controller) == true
                            ToggleGlyph(symbol: id.symbol(isOn: on), size: 10)
                                .foregroundStyle(on ? id.activeTint : Color.secondary.opacity(0.7))
                                .accessibilityHidden(true)
                        }
                    }
                }
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(run.section.title)
        .accessibilityLabel(run.section.title)
        .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
        .accessibilityHint("Shows or hides the section")
        .accessibilityFocused(a11yFocus, equals: .section(run.section))
        .focusRing(current == .section(run.section))
    }

    private func tile(_ id: ToggleID) -> some View {
        let on = ToggleActions.isOn(id, controller: controller) == true
        let enabled = controller.toggleAvailability.isEnabled(id)
        return Button {
            guard isInteractive, enabled, !blocked else { return }
            ToggleActions.trigger(id, controller: controller)
        } label: {
            VStack(spacing: 4) {
                ToggleGlyph(symbol: id.symbol(isOn: on), size: 14)
                    .foregroundStyle(on ? Color.white : Color.primary.opacity(0.75))
                    .frame(width: 38, height: 38)
                    .background {
                        Circle().fill(
                            on
                                ? AnyShapeStyle(id.activeTint.gradient)
                                : AnyShapeStyle(Color.primary.opacity(0.09))
                        )
                    }
                    .overlay {
                        if contrast == .increased {
                            Circle().strokeBorder(
                                on ? id.activeTint : Color.primary.opacity(0.55),
                                lineWidth: on ? 2 : 1
                            )
                        }
                    }
                    .accessibilityHidden(true)
                Text(id.gridTitle)
                    .font(.caption2.weight(on ? .semibold : .regular))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .top)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isInteractive && (blocked || !enabled))
        .opacity(enabled ? 1 : 0.4)
        .help(ToggleActions.help(id, controller: controller))
        .accessibilityLabel(id.title)
        .accessibilityValue(ToggleActions.accessibilityValue(id, controller: controller))
        .accessibilityHint(ToggleActions.accessibilityHint(id))
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityFocused(a11yFocus, equals: .tile(id))
        .focusRing(current == .tile(id))
    }
}

struct FocusRing: ViewModifier {
    var active: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
    }
}

extension View {
    func focusRing(_ active: Bool) -> some View {
        modifier(FocusRing(active: active))
    }
}
