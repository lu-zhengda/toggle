import SwiftUI

extension Sample {
    static var all: [Item] { sections.flatMap(\.items) }
    static func item(_ id: String) -> Item { all.first { $0.id == id }! }
    static let shortNames: [String: String] = [
        "lpm": "Low Power", "stage": "Stage Manager", "desk": "Desktop Icons", "hidden": "Hidden Files",
        "ext": "Extensions", "dock": "Dock Auto-hide", "dnd": "Do Not Disturb",
    ]
}

struct Framed<C: View>: View {
    let content: C
    init(@ViewBuilder _ c: () -> C) { content = c() }
    var body: some View { content.padding(.horizontal, 50).padding(.vertical, 40).background(Backdrop()) }
}

struct PanelShell<C: View>: View {
    let width: CGFloat
    let content: C
    init(width: CGFloat, @ViewBuilder _ c: () -> C) { self.width = width; content = c() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14).frame(width: width)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26))
    }
}

func glassCircleButton(_ s: String, size: CGFloat = 26) -> some View {
    Image(systemName: s).font(.system(size: 11, weight: .semibold))
        .frame(width: size, height: size).foregroundStyle(.secondary)
        .glassEffect(.regular, in: Circle())
}

// MARK: A — dense, icon-only, quick actions live in the header

struct ATile: View {
    let item: Item
    var focused = false
    var body: some View {
        let on = item.isOn == true
        GlyphView(glyph: item.glyph, size: 14)
            .foregroundStyle(on ? Color.white : Color.primary.opacity(0.8))
            .frame(width: 42, height: 42)
            .glassEffect(on ? .regular.tint(item.tint) : .regular, in: Circle())
            .overlay { if focused { Circle().strokeBorder(Color.accentColor, lineWidth: 2.5).padding(-3) } }
    }
}

struct GridA: View {
    var body: some View {
        let all = Sample.all
        let rows = stride(from: 0, to: all.count, by: 6).map { Array(all[$0..<min($0 + 6, all.count)]) }
        PanelShell(width: 310) {
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(Sample.actions) { a in
                        GlyphView(glyph: a.glyph, size: 12).foregroundStyle(.secondary).frame(width: 29, height: 26)
                    }
                }
                .padding(.horizontal, 4).glassEffect(.regular, in: Capsule())
                Spacer(minLength: 0)
                ViewSwitch(mode: .grid)
                glassCircleButton("gearshape.fill")
            }
            Group {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: 6) { ForEach(r) { ATile(item: $0, focused: $0.id == "awake") } }
                    }
                }
            }
            HStack(spacing: 6) {
                Circle().fill(Color.brown).frame(width: 8, height: 8)
                Text("Keep Awake").font(.system(size: 11.5, weight: .semibold))
                Text("1 hr left").font(.system(size: 11.5)).foregroundStyle(.secondary)
                Spacer()
                Text("16 toggles").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: B — labeled, Control Center–style mixed sizes, actions as ghost tiles

struct LTile: View {
    let item: Item
    var w: CGFloat = 72
    var h: CGFloat = 72
    var body: some View {
        let on = item.isOn == true
        VStack(alignment: .leading, spacing: 0) {
            GlyphView(glyph: item.glyph, size: 12)
                .frame(width: 26, height: 26)
                .background(Circle().fill(on ? Color.white.opacity(0.28) : Color.primary.opacity(0.09)))
            Spacer(minLength: 2)
            Text(Sample.shortNames[item.id] ?? item.name)
                .font(.system(size: 10.5, weight: .medium)).lineLimit(2).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(on ? Color.white : Color.primary)
        .padding(9).frame(width: w, height: h, alignment: .topLeading)
        .glassEffect(on ? .regular.tint(item.tint) : .regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct WideTile: View {
    let item: Item
    var subtitle: String
    var ring: Double? = nil
    var body: some View {
        let on = item.isOn == true
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(on ? Color.white.opacity(0.28) : Color.primary.opacity(0.09))
                if let r = ring {
                    Circle().trim(from: 0, to: r).stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90)).padding(1.5)
                }
                GlyphView(glyph: item.glyph, size: 13)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(.system(size: 10.5)).opacity(0.8).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(on ? Color.white : Color.primary)
        .padding(.horizontal, 10).frame(width: 152, height: 72)
        .glassEffect(on ? .regular.tint(item.tint) : .regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SoundTile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sound").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Speakers").font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.14))
                    Capsule().fill(Color.primary.opacity(0.75)).frame(width: 52)
                }.frame(height: 8)
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).frame(width: 152, height: 72)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct ConnModule: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(["wifi", "bt", "airdrop"], id: \.self) { id in
                let it = Sample.item(id)
                HStack(spacing: 9) {
                    GlyphView(glyph: it.glyph, size: 12).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(Circle().fill(Color.blue.gradient))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(it.name).font(.system(size: 12, weight: .semibold))
                        Text(it.value ?? "On").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4).frame(width: 152, height: 152)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct GhostTile: View {
    let item: Item
    var body: some View {
        VStack(spacing: 4) {
            GlyphView(glyph: item.glyph, size: 14).foregroundStyle(.secondary)
            Text(item.name).font(.system(size: 9.5, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(width: 72, height: 54)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}

struct GridB: View {
    var body: some View {
        let I = Sample.item
        PanelShell(width: 340) {
            HStack(spacing: 6) {
                Text("Toggle").font(.system(size: 14, weight: .semibold))
                Spacer()
                ViewSwitch(mode: .grid)
                glassCircleButton("arrow.clockwise"); glassCircleButton("gearshape.fill")
            }
            Group {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        ConnModule()
                        VStack(spacing: 8) {
                            WideTile(item: I("awake"), subtitle: "1 hr left", ring: 0.62)
                            HStack(spacing: 8) { LTile(item: I("dark")); LTile(item: I("truetone")) }
                        }
                    }
                    HStack(spacing: 8) { WideTile(item: I("airpods"), subtitle: "Not connected"); SoundTile() }
                    HStack(spacing: 8) { ForEach(["night", "lpm", "dnd", "stage"], id: \.self) { LTile(item: I($0)) } }
                    HStack(spacing: 8) { ForEach(["desk", "hidden", "ext", "dock"], id: \.self) { LTile(item: I($0)) } }
                    HStack(spacing: 8) { ForEach(Sample.actions) { GhostTile(item: $0) } }
                }
            }
        }
    }
}

// MARK: C — section cards (glass), labeled flat tiles, collapsible sections, bottom strip

struct CTile: View {
    let item: Item
    var body: some View {
        let on = item.isOn == true
        VStack(spacing: 4) {
            GlyphView(glyph: item.glyph, size: 14)
                .foregroundStyle(on ? Color.white : Color.primary.opacity(0.75))
                .frame(width: 38, height: 38)
                .background(Circle().fill(on ? AnyShapeStyle(item.tint.gradient) : AnyShapeStyle(Color.primary.opacity(0.09))))
            Text(Sample.shortNames[item.id] ?? item.name)
                .font(.system(size: 10, weight: on ? .semibold : .regular)).multilineTextAlignment(.center)
                .lineLimit(2).frame(height: 26, alignment: .top)
        }
        .frame(width: 66)
    }
}

struct CCard: View {
    let section: Section_
    var collapsed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.title.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if collapsed {
                    HStack(spacing: 8) {
                        ForEach(section.items) { it in
                            GlyphView(glyph: it.glyph, size: 10)
                                .foregroundStyle(it.isOn == true ? it.tint : Color.secondary.opacity(0.7))
                        }
                    }
                }
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            if !collapsed {
                HStack(spacing: 2) { ForEach(section.items) { CTile(item: $0) } }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct GridC: View {
    var body: some View {
        PanelShell(width: 340) {
            HStack(spacing: 6) {
                Text("Toggle").font(.system(size: 14, weight: .semibold))
                Spacer()
                ViewSwitch(mode: .grid)
                glassCircleButton("arrow.clockwise"); glassCircleButton("gearshape.fill")
            }
            Group {
                VStack(spacing: 8) {
                    ForEach(Array(Sample.sections.enumerated()), id: \.element.id) { i, s in
                        CCard(section: s, collapsed: i == 3)
                    }
                    HStack(spacing: 0) {
                        ForEach(Sample.actions) { a in
                            VStack(spacing: 2) {
                                GlyphView(glyph: a.glyph, size: 12)
                                Text(a.name == "More" ? "More" : a.name).font(.system(size: 9)).lineLimit(1)
                            }
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 42).glassEffect(.regular, in: Capsule())
                }
            }
        }
    }
}
