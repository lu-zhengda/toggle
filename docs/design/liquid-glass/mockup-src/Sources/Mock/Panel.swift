import SwiftUI

enum Mode: String, CaseIterable { case grid, list }

// Wallpaper-like backdrop so the glass has something to refract.
struct Backdrop: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        ZStack {
            LinearGradient(colors: scheme == .dark
                           ? [Color(red: 0.05, green: 0.07, blue: 0.20), Color(red: 0.22, green: 0.05, blue: 0.28)]
                           : [Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.98, green: 0.74, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(scheme == .dark ? Color.teal.opacity(0.55) : Color.pink.opacity(0.55))
                .frame(width: 320).blur(radius: 60).offset(x: -150, y: -180)
            Circle().fill(scheme == .dark ? Color.purple.opacity(0.6) : Color.yellow.opacity(0.6))
                .frame(width: 280).blur(radius: 60).offset(x: 170, y: 220)
            Circle().fill(scheme == .dark ? Color.blue.opacity(0.5) : Color.mint.opacity(0.6))
                .frame(width: 220).blur(radius: 50).offset(x: 140, y: -60)
        }
    }
}

struct ViewSwitch: View {
    var mode: Mode
    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                seg("square.grid.2x2", .grid, "Grid")
                seg("list.bullet", .list, "List")
            }
            .padding(2)
            .glassEffect(.regular, in: Capsule())
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View")
    }
    func seg(_ sym: String, _ m: Mode, _ label: String) -> some View {
        Image(systemName: sym).font(.system(size: 11, weight: .semibold))
            .frame(width: 30, height: 22)
            .foregroundStyle(m == mode ? Color.primary : Color.secondary)
            .background {
                if m == mode { Capsule().fill(.primary.opacity(0.12)) }
            }
            .accessibilityLabel(label)
    }
}

struct Header: View {
    var mode: Mode
    var body: some View {
        HStack(spacing: 6) {
            Text("Toggle").font(.system(size: 14, weight: .semibold))
            Spacer()
            ViewSwitch(mode: mode)
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    iconBtn("arrow.clockwise")
                    iconBtn("gearshape.fill")
                }
            }
        }
    }
    func iconBtn(_ s: String) -> some View {
        Image(systemName: s).font(.system(size: 11, weight: .semibold))
            .frame(width: 26, height: 26)
            .foregroundStyle(.secondary)
            .glassEffect(.regular, in: Circle())
    }
}

// MARK: Grid

struct Tile: View {
    let item: Item
    var body: some View {
        let on = item.isOn == true
        GlyphView(glyph: item.glyph, size: 16)
            .foregroundStyle(on ? Color.white : Color.primary.opacity(0.8))
            .frame(width: 48, height: 48)
            .glassEffect(on ? .regular.tint(item.tint) : .regular, in: Circle())
            .frame(maxWidth: .infinity)
            .help(item.name)
    }
}

struct GridBody: View {
    var sections = Sample.sections
    var body: some View {
        Group {
            VStack(spacing: 12) {
                ForEach(sections) { s in
                    HStack(spacing: 6) { ForEach(s.items) { Tile(item: $0) } }
                }
                HStack(spacing: 6) {
                    ForEach(Sample.actions) { a in
                        GlyphView(glyph: a.glyph, size: 14)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).frame(height: 34)
                    }
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: List

struct Row: View {
    let item: Item
    var expanded = false
    var focused = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                let on = item.isOn == true
                GlyphView(glyph: item.glyph, size: 12)
                    .foregroundStyle(on ? Color.white : Color.primary.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .glassEffect(on ? .regular.tint(item.tint) : .regular, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(.system(size: 13, weight: .medium))
                    if let v = item.value {
                        Text(v).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if item.options != nil {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .frame(width: 22, height: 22)
                        .glassEffect(.regular, in: Circle())
                        .accessibilityLabel("\(item.name) options")
                }
                if let on = item.isOn {
                    MiniSwitch(on: on, tint: item.tint)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(minHeight: 42)
            if expanded, let opts = item.options {
                VStack(spacing: 2) {
                    ForEach(opts, id: \.self) { o in
                        HStack {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                .opacity(o == item.selected ? 1 : 0)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 16)
                            Text(o).font(.system(size: 12.5))
                            Spacer()
                        }
                        .padding(.horizontal, 10).frame(height: 26)
                        .background {
                            if o == item.selected {
                                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.16))
                            }
                        }
                    }
                }
                .padding(6)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 8).padding(.bottom, 8)
                .transition(.asymmetric(insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .background {
            if expanded || focused {
                RoundedRectangle(cornerRadius: 16).fill(.primary.opacity(0.06))
            }
        }
        .overlay {
            if focused { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor, lineWidth: 2) }
        }
    }
}

struct ListBody: View {
    var expandedID: String? = nil
    var focusedID: String? = nil
    var sections = Sample.sections
    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sections) { s in
                    Text(s.title.uppercased()).font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary).padding(.leading, 10).padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(s.items) { Row(item: $0, expanded: $0.id == expandedID, focused: $0.id == focusedID) }
                    }
                    .padding(2)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                }
                HStack(spacing: 6) {
                    ForEach(Sample.actions) { a in
                        GlyphView(glyph: a.glyph, size: 13).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).frame(height: 32)
                    }
                }
                .glassEffect(.regular, in: Capsule())
                .padding(.top, 4)
            }
        }
    }
}

struct Panel: View {
    var mode: Mode
    var expandedID: String? = nil
    var focusedID: String? = nil
    var sections = Sample.sections
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Header(mode: mode)
            if mode == .grid { GridBody(sections: sections) }
            else { ListBody(expandedID: expandedID, focusedID: focusedID, sections: sections) }
        }
        .padding(14)
        .frame(width: mode == .grid ? 300 : 320)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26))
    }
}

struct Scene_: View {
    var mode: Mode
    var expandedID: String? = nil
    var focusedID: String? = nil
    var sections = Sample.sections
    var body: some View {
        Panel(mode: mode, expandedID: expandedID, focusedID: focusedID, sections: sections)
            .padding(.horizontal, 50).padding(.vertical, 40)
            .background(Backdrop())
    }
}

// Drawn to match the macOS 26 small switch: ImageRenderer can't draw AppKit-backed controls.
struct MiniSwitch: View {
    var on: Bool
    var tint: Color = .blue
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? Color.accentColor : Color.primary.opacity(0.14))
            Capsule().fill(.white).frame(width: 20, height: 16)
                .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
                .padding(2)
        }
        .frame(width: 34, height: 20)
        .accessibilityElement().accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? "On" : "Off")
    }
}
