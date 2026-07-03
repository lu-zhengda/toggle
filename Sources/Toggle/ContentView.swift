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

/// A circular icon button. No text label — the name lives in the hover tooltip.
private struct IconButton: View {
    let glyph: IconGlyph
    let title: String
    var isOn: Bool = false
    var disabled: Bool = false
    var activeColor: Color = .accentColor
    var idleTint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            glyphView
                .frame(width: 46, height: 46)
                .background(Circle().fill(isOn ? activeColor : Color.gray.opacity(0.15)))
                .foregroundStyle(isOn ? Color.white : idleTint)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .help(title)
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

/// Audio output: tap cycles devices, right-click picks a specific one.
private struct AudioOutputTile: View {
    @ObservedObject var controller: SystemController

    var body: some View {
        IconButton(glyph: .symbol("hifispeaker.fill"),
                   title: "Audio Output: \(controller.audioOutputName)",
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
    @Environment(\.openWindow) private var openWindow

    private let columns = Array(repeating: GridItem(.fixed(46), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            LazyVGrid(columns: columns, spacing: 12) { toggles }
            Divider()
            LazyVGrid(columns: columns, spacing: 12) { actions }
        }
        .padding(14)
        .frame(width: 248)
        .onAppear { controller.refresh() }
    }

    private var header: some View {
        HStack {
            Text("Toggle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit Toggle")
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
                   action: controller.toggleTrueTone)

        IconButton(glyph: .symbol(controller.muted ? "speaker.slash.fill" : "speaker.wave.2.fill"),
                   title: controller.muted ? "Unmute" : "Mute",
                   isOn: controller.muted, action: controller.toggleMute)

        // Keep Awake — tap toggles indefinitely; right-click for a timer.
        IconButton(glyph: .symbol("cup.and.saucer.fill"), title: keepAwakeTitle,
                   isOn: controller.keepAwake, action: controller.toggleKeepAwake)
            .contextMenu {
                Button("Keep awake for 15 minutes") { controller.setKeepAwake(true, minutes: 15) }
                Button("Keep awake for 30 minutes") { controller.setKeepAwake(true, minutes: 30) }
                Button("Keep awake for 1 hour") { controller.setKeepAwake(true, minutes: 60) }
                Button("Keep awake for 2 hours") { controller.setKeepAwake(true, minutes: 120) }
                Divider()
                Button("Keep awake indefinitely") { controller.setKeepAwake(true) }
                Button("Turn off") { controller.setKeepAwake(false) }
            }

        IconButton(glyph: .symbol("wifi"), title: "Wi-Fi",
                   isOn: controller.wifi, action: controller.toggleWifi)

        if controller.bluetoothAvailable {
            IconButton(glyph: .bluetooth, title: "Bluetooth",
                       isOn: controller.bluetooth, action: controller.toggleBluetooth)
        }
        if controller.airPodsAvailable {
            IconButton(glyph: .symbol("airpods"),
                       title: controller.airPodsConnected ? "Disconnect AirPods" : "Connect AirPods",
                       isOn: controller.airPodsConnected, action: controller.toggleAirPods)
        }

        IconButton(glyph: .symbol("bell.slash.fill"), title: "Do Not Disturb",
                   isOn: controller.doNotDisturb, action: controller.toggleDoNotDisturb)

        AudioOutputTile(controller: controller)
        AirDropTile(controller: controller)

        IconButton(glyph: .symbol("square.grid.2x2.fill"), title: "Hide Desktop Icons",
                   isOn: controller.hideDesktopIcons, action: controller.toggleHideDesktopIcons)
        IconButton(glyph: .symbol("eye.fill"), title: "Show Hidden Files",
                   isOn: controller.showHiddenFiles, action: controller.toggleHiddenFiles)
        IconButton(glyph: .symbol("doc.badge.ellipsis"), title: "Show File Extensions",
                   isOn: controller.showFileExtensions, action: controller.toggleFileExtensions)
        IconButton(glyph: .symbol("dock.arrow.down.rectangle"), title: "Dock Auto-hide",
                   isOn: controller.dockAutohide, action: controller.toggleDockAutohide)
        IconButton(glyph: .symbol("rectangle.stack.fill"), title: "Stage Manager",
                   isOn: controller.stageManager, action: controller.toggleStageManager)
    }

    @ViewBuilder private var actions: some View {
        if controller.lowPowerModeAvailable {
            IconButton(glyph: .symbol("leaf.fill"), title: "Low Power Mode",
                       isOn: controller.lowPowerMode, activeColor: .yellow,
                       action: controller.toggleLowPowerMode)
        }

        IconButton(glyph: .symbol("display"), title: "Screen Saver", action: controller.startScreenSaver)
        IconButton(glyph: .symbol("lock.fill"), title: "Lock Screen", action: controller.lockScreen)
        IconButton(glyph: .symbol("moon.zzz.fill"), title: "Sleep Display", action: controller.sleepDisplay)
        IconButton(glyph: .symbol("bed.double.fill"), title: "Sleep Now", action: controller.sleepNow)
        IconButton(glyph: .symbol("trash.fill"), title: "Empty Trash",
                   idleTint: .red, action: controller.emptyTrash)
        IconButton(glyph: .symbol("clipboard.fill"), title: "Clear Clipboard",
                   action: controller.clearClipboard)
        IconButton(glyph: .symbol("eject.fill"), title: "Eject All Disks",
                   action: controller.ejectAllDisks)
    }

    private var keepAwakeTitle: String {
        guard controller.keepAwake else { return "Keep Awake" }
        if let until = controller.keepAwakeUntil {
            let mins = max(0, Int(until.timeIntervalSinceNow / 60) + 1)
            return "Keep Awake (\(mins) min left)"
        }
        return "Keep Awake (on, \(controller.keepAwakeMode.commandEquivalent))"
    }
}
