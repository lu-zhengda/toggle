import SwiftUI

/// The Bluetooth rune — there's no SF Symbol for it, so we stroke it ourselves.
/// Polyline taken from the Feather "bluetooth" icon (24×24 viewBox).
private struct BluetoothShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [CGPoint] = [
            .init(x: 6.5, y: 6.5), .init(x: 17.5, y: 17.5), .init(x: 12, y: 23),
            .init(x: 12, y: 1), .init(x: 17.5, y: 6.5), .init(x: 6.5, y: 17.5),
        ]
        let scale = min(rect.width, rect.height) / 24
        let dx = rect.minX + (rect.width - 24 * scale) / 2
        let dy = rect.minY + (rect.height - 24 * scale) / 2
        var path = Path()
        for (i, p) in pts.enumerated() {
            let q = CGPoint(x: dx + p.x * scale, y: dy + p.y * scale)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        return path
    }
}

/// The AirDrop mark — no SF Symbol exists, so we draw it: concentric arcs (open
/// at the bottom) plus a downward triangle, matching the native glyph.
private struct AirDropArcs: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let cx = rect.midX
        let cy = rect.minY + 10 * s
        var path = Path()
        for r in [3.5, 6.5, 9.5] as [CGFloat] {
            let radius = r * s
            var deg = 128.0
            var first = true
            while deg <= 412.0 {
                let a = deg * .pi / 180
                let p = CGPoint(x: cx + radius * cos(a), y: cy + radius * sin(a))
                if first { path.move(to: p); first = false } else { path.addLine(to: p) }
                deg += 6
            }
        }
        return path
    }
}

private struct AirDropTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let cx = rect.midX
        let cy = rect.minY + 10 * s
        var path = Path()
        path.move(to: CGPoint(x: cx - 2.4 * s, y: cy + 2.8 * s))
        path.addLine(to: CGPoint(x: cx + 2.4 * s, y: cy + 2.8 * s))
        path.addLine(to: CGPoint(x: cx, y: cy + 8 * s))
        path.closeSubpath()
        return path
    }
}

private enum IconGlyph {
    case symbol(String)
    case bluetooth
    case airdrop
}

/// The visual treatment shared by icon buttons and the overflow menu. The
/// entire glyph is decorative: the containing control supplies its own clear
/// accessibility label, value, and hint.
private struct IconTileVisual: View {
    let glyph: IconGlyph
    var isOn = false
    var activeColor: Color = .accentColor
    var idleTint: Color = .primary

    var body: some View {
        glyphView
            .frame(width: 46, height: 46)
            .background(
                Circle().fill(
                    isOn ? activeColor.opacity(0.16) : Color.primary.opacity(0.07)
                )
            )
            .overlay {
                Circle().stroke(
                    isOn ? activeColor.opacity(0.9) : Color.primary.opacity(0.08),
                    lineWidth: isOn ? 1.5 : 0.5
                )
            }
            .overlay(alignment: .bottomTrailing) {
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(activeColor)
                        .background(.regularMaterial, in: Circle())
                        .offset(x: 1, y: 1)
                }
            }
            .foregroundStyle(isOn ? activeColor : idleTint)
            .contentShape(Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder private var glyphView: some View {
        switch glyph {
        case .symbol(let name):
            Image(systemName: name).font(.system(size: 18, weight: .medium))
        case .bluetooth:
            BluetoothShape()
                .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 19, height: 19)
        case .airdrop:
            ZStack {
                AirDropArcs().stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                AirDropTriangle()
            }
            .frame(width: 20, height: 20)
        }
    }
}

/// A circular icon button. No text label — the name lives in the hover tooltip.
private struct IconButton: View {
    let glyph: IconGlyph
    let title: String
    /// `nil` means this is a momentary action rather than an on/off control.
    var isOn: Bool? = nil
    var disabled: Bool = false
    var activeColor: Color = .accentColor
    var idleTint: Color = .primary
    var accessibilityLabel: String? = nil
    var accessibilityValue: String? = nil
    var accessibilityHint: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconTileVisual(
                glyph: glyph,
                isOn: isOn == true,
                activeColor: activeColor,
                idleTint: idleTint
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .help(title)
        .accessibilityLabel(Text(resolvedAccessibilityLabel))
        .accessibilityValue(Text(resolvedAccessibilityValue))
        .accessibilityHint(Text(resolvedAccessibilityHint))
        .accessibilityAddTraits(isOn == true ? .isSelected : [])
    }

    private var resolvedAccessibilityLabel: String {
        accessibilityLabel ?? title
    }

    private var resolvedAccessibilityValue: String {
        accessibilityValue ?? isOn.map { $0 ? "On" : "Off" } ?? ""
    }

    private var resolvedAccessibilityHint: String {
        if let accessibilityHint { return accessibilityHint }
        if disabled { return "Unavailable on this Mac or display." }
        if let isOn {
            return isOn
                ? "Turns \(resolvedAccessibilityLabel) off."
                : "Turns \(resolvedAccessibilityLabel) on."
        }
        return "Performs \(resolvedAccessibilityLabel)."
    }
}

/// Audio output: tap cycles devices, right-click picks a specific one.
private struct AudioOutputTile: View {
    @ObservedObject var controller: SystemController

    var body: some View {
        IconButton(glyph: .symbol("hifispeaker.fill"),
                   title: "Audio Output: \(controller.audioOutputName)",
                   accessibilityLabel: "Audio Output",
                   accessibilityValue: controller.audioOutputName,
                   accessibilityHint: "Switches to the next output. Open the context menu to choose a device.",
                   action: controller.cycleAudioOutput)
            .contextMenu {
                ForEach(controller.audioDevices) { device in
                    Button { controller.selectAudioDevice(device.id) } label: {
                        Text(label(device.name, on: device.id == controller.audioOutputID))
                    }
                }
            }
    }

    private func label(_ name: String, on: Bool) -> String { on ? "✓ \(name)" : name }
}

/// AirDrop visibility: tap cycles Off/Contacts/Everyone, right-click picks.
private struct AirDropTile: View {
    @ObservedObject var controller: SystemController

    var body: some View {
        IconButton(glyph: .airdrop,
                   title: "AirDrop: \(controller.airDropMode)",
                   isOn: controller.airDropMode != "Off",
                   accessibilityLabel: "AirDrop",
                   accessibilityValue: controller.airDropMode,
                   accessibilityHint: "Cycles AirDrop visibility. Open the context menu to choose a mode.",
                   action: controller.cycleAirDrop)
            .contextMenu {
                ForEach(SystemController.airDropModes, id: \.self) { mode in
                    Button { controller.setAirDrop(mode) } label: {
                        Text(mode == controller.airDropMode ? "✓ \(mode)" : mode)
                    }
                }
            }
    }
}

struct ContentView: View {
    @ObservedObject var controller: SystemController

    private let columns = Array(repeating: GridItem(.fixed(46), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            LazyVGrid(columns: columns, spacing: 12) { toggles }
                .disabled(
                    !controller.hasLoadedState
                        || controller.isRefreshing
                        || !controller.busyActions.isEmpty
                )
                .opacity(controller.hasLoadedState ? 1 : 0.55)
                .accessibilityHidden(!controller.hasLoadedState)
            Divider()
            LazyVGrid(columns: columns, spacing: 12) { actions }
                .disabled(controller.isRefreshing || !controller.busyActions.isEmpty)
            footer
        }
        .padding(14)
        .frame(width: 248)
        .onAppear { controller.refresh() }
    }

    private var header: some View {
        HStack(spacing: 2) {
            Text("Toggle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()

            Button(action: controller.refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(controller.isRefreshing || !controller.busyActions.isEmpty)
            .opacity(controller.isRefreshing || !controller.busyActions.isEmpty ? 0.45 : 1)
            .help(controller.isRefreshing ? "Refreshing…" : "Refresh")
            .accessibilityLabel("Refresh system state")
            .accessibilityHint("Updates all toggle states.")

            SettingsLink {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens Toggle settings.")
        }
    }

    @ViewBuilder private var toggles: some View {
        IconButton(glyph: .symbol("moon.fill"), title: "Dark Mode",
                   isOn: controller.darkMode, action: controller.toggleDarkMode)

        if controller.nightShiftAvailable {
            IconButton(glyph: .symbol("sun.max.fill"), title: "Night Shift",
                       isOn: controller.nightShift, action: controller.toggleNightShift)
        }

        // Always shown; disabled (greyed) when the display/Mac lacks True Tone.
        IconButton(glyph: .symbol("sun.haze.fill"), title: "True Tone",
                   isOn: controller.trueTone,
                   disabled: !controller.trueToneAvailable,
                   accessibilityLabel: "True Tone",
                   action: controller.toggleTrueTone)

        IconButton(glyph: .symbol(controller.muted ? "speaker.slash.fill" : "speaker.wave.2.fill"),
                   title: controller.muted ? "Unmute" : "Mute",
                   isOn: controller.muted,
                   accessibilityLabel: "Output Mute",
                   accessibilityValue: controller.muted ? "Muted" : "Not muted",
                   accessibilityHint: controller.muted ? "Unmutes audio output." : "Mutes audio output.",
                   action: controller.toggleMute)

        // Keep Awake — tap toggles indefinitely; right-click for a timer.
        IconButton(glyph: .symbol("cup.and.saucer.fill"), title: keepAwakeTitle,
                   isOn: controller.keepAwake,
                   accessibilityLabel: "Keep Awake",
                   accessibilityValue: keepAwakeAccessibilityValue,
                   accessibilityHint: controller.keepAwake
                       ? "Turns Keep Awake off. Open the context menu to choose a timer."
                       : "Turns Keep Awake on using the default duration. Open the context menu to choose a timer.",
                   action: controller.toggleKeepAwake)
            .contextMenu {
                Button("Keep awake for 15 minutes") { controller.setKeepAwake(true, minutes: 15) }
                Button("Keep awake for 30 minutes") { controller.setKeepAwake(true, minutes: 30) }
                Button("Keep awake for 1 hour") { controller.setKeepAwake(true, minutes: 60) }
                Button("Keep awake for 2 hours") { controller.setKeepAwake(true, minutes: 120) }
                Divider()
                Button("Keep awake indefinitely") { controller.setKeepAwake(true) }
                Button("Turn off") { controller.setKeepAwake(false) }
            }

        if controller.lowPowerModeAvailable {
            IconButton(glyph: .symbol("leaf.fill"), title: "Low Power Mode",
                       isOn: controller.lowPowerMode, activeColor: .orange,
                       action: controller.toggleLowPowerMode)
        }

        IconButton(glyph: .symbol("wifi"), title: "Wi-Fi",
                   isOn: controller.wifi,
                   disabled: !controller.wifiAvailable,
                   accessibilityLabel: "Wi-Fi",
                   action: controller.toggleWifi)

        if controller.bluetoothAvailable {
            IconButton(glyph: .bluetooth, title: "Bluetooth",
                       isOn: controller.bluetooth, action: controller.toggleBluetooth)
        }
        if controller.airPodsAvailable {
            IconButton(glyph: .symbol("airpods"),
                       title: controller.airPodsConnected ? "Disconnect AirPods" : "Connect AirPods",
                       isOn: controller.airPodsConnected,
                       accessibilityLabel: "AirPods",
                       accessibilityValue: controller.airPodsConnected ? "Connected" : "Disconnected",
                       accessibilityHint: controller.airPodsConnected
                           ? "Disconnects AirPods."
                           : "Connects AirPods.",
                       action: controller.toggleAirPods)
        }

        IconButton(glyph: .symbol("bell.slash.fill"), title: "Toggle Do Not Disturb",
                   accessibilityLabel: "Do Not Disturb",
                   accessibilityHint: "Toggles Do Not Disturb through Control Center. Requires Accessibility permission.",
                   action: controller.toggleDoNotDisturb)

        AudioOutputTile(controller: controller)
        AirDropTile(controller: controller)

        IconButton(glyph: .symbol("square.grid.2x2.fill"),
                   title: controller.hideDesktopIcons ? "Show Desktop Icons" : "Hide Desktop Icons",
                   isOn: controller.hideDesktopIcons,
                   accessibilityLabel: "Desktop Icons",
                   accessibilityValue: controller.hideDesktopIcons ? "Hidden" : "Visible",
                   accessibilityHint: controller.hideDesktopIcons
                       ? "Shows desktop icons."
                       : "Hides desktop icons.",
                   action: controller.toggleHideDesktopIcons)
        IconButton(glyph: .symbol("eye.fill"), title: "Show Hidden Files",
                   isOn: controller.showHiddenFiles,
                   accessibilityLabel: "Hidden Files",
                   accessibilityValue: controller.showHiddenFiles ? "Shown" : "Hidden",
                   action: controller.toggleHiddenFiles)
        IconButton(glyph: .symbol("doc.badge.ellipsis"), title: "Show File Extensions",
                   isOn: controller.showFileExtensions,
                   accessibilityLabel: "File Extensions",
                   accessibilityValue: controller.showFileExtensions ? "Shown" : "Hidden",
                   action: controller.toggleFileExtensions)
        IconButton(glyph: .symbol("dock.arrow.down.rectangle"), title: "Dock Auto-hide",
                   isOn: controller.dockAutohide, action: controller.toggleDockAutohide)
        IconButton(glyph: .symbol("rectangle.stack.fill"), title: "Stage Manager",
                   isOn: controller.stageManager, action: controller.toggleStageManager)
    }

    @ViewBuilder private var actions: some View {
        IconButton(glyph: .symbol("display"), title: "Screen Saver", action: controller.startScreenSaver)
        IconButton(glyph: .symbol("lock.fill"), title: "Lock Screen", action: controller.lockScreen)
        IconButton(glyph: .symbol("moon.zzz.fill"), title: "Sleep Display", action: controller.sleepDisplay)
        MoreActionsMenu(controller: controller)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if let feedback = controller.feedback, feedback.isError {
                feedbackContent(feedback)
            } else if controller.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing…")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Refreshing system state")
            } else if !controller.busyActions.isEmpty {
                ProgressView()
                    .controlSize(.small)
                Text("Applying change…")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Applying system change")
            } else if let feedback = controller.feedback {
                feedbackContent(feedback)
            } else {
                Text("Ready")
                    .hidden()
            }
        }
        .font(.caption)
        .foregroundStyle(
            !controller.isRefreshing && controller.feedback?.isError == true
                ? Color.red
                : Color.secondary
        )
        .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16, alignment: .leading)
        .accessibilityElement(children: .combine)
        .help(controller.feedback?.message ?? "Status")
    }

    @ViewBuilder
    private func feedbackContent(_ feedback: ActionFeedback) -> some View {
        Image(systemName: feedback.symbol)
            .accessibilityHidden(true)
        Text(feedback.message)
            .lineLimit(1)
            .truncationMode(.tail)
        Spacer(minLength: 0)
    }

    private var keepAwakeTitle: String {
        guard controller.keepAwake else { return "Keep Awake" }
        if let until = controller.keepAwakeUntil {
            let mins = max(0, Int(until.timeIntervalSinceNow / 60) + 1)
            return "Keep Awake (\(mins) min left)"
        }
        return "Keep Awake (on, \(controller.keepAwakeMode.commandEquivalent))"
    }

    private var keepAwakeAccessibilityValue: String {
        guard controller.keepAwake else { return "Off" }
        if let until = controller.keepAwakeUntil {
            let mins = max(0, Int(until.timeIntervalSinceNow / 60) + 1)
            return "On, \(mins) minutes remaining"
        }
        return "On indefinitely"
    }
}

/// Less-frequent or disruptive actions live behind a labeled menu while the
/// grid itself remains compact and icon-only.
private struct MoreActionsMenu: View {
    @ObservedObject var controller: SystemController

    var body: some View {
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
            IconTileVisual(glyph: .symbol("ellipsis"))
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .frame(width: 46, height: 46)
        .contentShape(Circle())
        .help("More Actions")
        .accessibilityLabel("More Actions")
        .accessibilityHint("Opens sleep, clipboard, disk, trash, and quit actions.")
    }
}
