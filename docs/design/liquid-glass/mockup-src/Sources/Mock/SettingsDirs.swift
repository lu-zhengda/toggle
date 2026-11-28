import SwiftUI

enum SData {
    static var ordered: [Item] {
        var items = Sample.all
        let hide: Set = ["stage", "desk", "dock"]
        for i in items.indices where hide.contains(items[i].id) { items[i].visible = false }
        return items
    }
    static var visibleSections: [Section_] {
        let hide: Set = ["stage", "desk", "dock"]
        return Sample.sections.map { Section_(id: $0.id, title: $0.title, items: $0.items.filter { !hide.contains($0.id) }) }
    }
    static let durations = ["15 minutes", "30 minutes", "1 hour", "2 hours", "5 hours", "Indefinitely"]
}

struct Card<C: View>: View {
    let title: String?
    var footnote: String? = nil
    let content: C
    init(_ title: String? = nil, footnote: String? = nil, @ViewBuilder _ c: () -> C) { self.title = title; self.footnote = footnote; content = c() }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let t = title { Text(t).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 4) }
            VStack(alignment: .leading, spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))
            if let f = footnote { Text(f).font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 4) }
        }
    }
}

struct FormRow<T: View>: View {
    let label: String
    var detail: String? = nil
    let trailing: T
    init(_ label: String, detail: String? = nil, @ViewBuilder trailing: () -> T) { self.label = label; self.detail = detail; self.trailing = trailing() }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 13))
                if let d = detail { Text(d).font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

struct OrderRow2: View {
    let item: Item
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "line.3.horizontal").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary).frame(width: 16)
            GlyphView(glyph: item.glyph, size: 10)
                .foregroundStyle(item.visible ? Color.white : Color.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(item.visible ? item.tint.gradient : Color.gray.opacity(0.25).gradient))
            Text(item.name).font(.system(size: 12.5)).foregroundStyle(item.visible ? .primary : .secondary)
            if item.options != nil {
                Text("Dropdown").font(.system(size: 9.5, weight: .medium))
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Capsule().fill(.primary.opacity(0.08))).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Show \(item.name)", isOn: .constant(item.visible)).toggleStyle(.checkbox).labelsHidden()
        }
        .padding(.horizontal, 12).frame(height: 30)
    }
}

struct OrderList: View {
    var body: some View {
        let items = SData.ordered
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, it in
                OrderRow2(item: it)
                if i < items.count - 1 { Divider().padding(.leading, 49) }
            }
        }
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))
    }
}

struct Pill: View {
    let text: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
    }
}

// MARK: Pages

struct KeepAwakePageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card("Durations in the Keep Awake menu", footnote: "Checked durations appear in the dropdown. The default is used when you click the switch.") {
                ForEach(Array(SData.durations.enumerated()), id: \.offset) { i, d in
                    HStack {
                        Toggle("Show \(d)", isOn: .constant(true)).toggleStyle(.checkbox).labelsHidden()
                        Text(d).font(.system(size: 13))
                        Spacer()
                        if d == "1 hour" { Pill(text: "Default", color: .accentColor) }
                        else { Text("Make default").font(.system(size: 11.5)).foregroundStyle(.secondary) }
                    }
                    .padding(.horizontal, 12).frame(height: 32)
                    if i < SData.durations.count - 1 { Divider().padding(.leading, 38) }
                }
            }
            Card("While Keep Awake is on") {
                FormRow("Prevent", detail: "Equivalent to caffeinate -i -d") {
                    Picker("", selection: .constant(2)) {
                        Text("System").tag(0); Text("Display").tag(1); Text("Both").tag(2)
                    }.pickerStyle(.segmented).frame(width: 190).labelsHidden()
                }
            }
        }
    }
}

struct PermissionsPageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                Text("2 of 3 ready").font(.system(size: 13, weight: .semibold))
                Text("Only Do Not Disturb needs the missing one.").font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(.leading, 4)
            Card {
                FormRow("Accessibility", detail: "Lets Toggle press Do Not Disturb in Control Center.") {
                    Pill(text: "Granted", color: .green)
                }
                Divider().padding(.leading, 12)
                FormRow("Automation", detail: "Lets Toggle talk to System Events for Dark Mode and Dock.") {
                    HStack(spacing: 8) { Pill(text: "Needs approval", color: .orange); Button("Open Settings") {}.controlSize(.small) }
                }
                Divider().padding(.leading, 12)
                FormRow("Launch at Login", detail: "Starts Toggle in the menu bar when you sign in.") {
                    Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden()
                }
            }
        }
    }
}

// MARK: A — sidebar

enum SPage: String, CaseIterable, Identifiable {
    case general = "General", toggles = "Toggles", keepAwake = "Keep Awake", permissions = "Permissions", about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: "gearshape"; case .toggles: "switch.2"; case .keepAwake: "cup.and.saucer"
        case .permissions: "hand.raised"; case .about: "info.circle"
        }
    }
}

final class PreviewStore: ObservableObject {
    static let shared = PreviewStore()
    @Published var light: NSImage?
    @Published var dark: NSImage?
}

struct SettingsA: View {
    @State var sel: SPage?
    var dark = false
    @ObservedObject var store = PreviewStore.shared
    var preview: NSImage? { dark ? store.dark : store.light }
    init(page: SPage, dark: Bool = false) { _sel = State(initialValue: page); self.dark = dark }
    var body: some View {
        HStack(spacing: 0) {
            // Hand-drawn sidebar: offscreen capture can't draw a real NavigationSplitView sidebar.
            VStack(alignment: .leading, spacing: 3) {
                Color.clear.frame(height: 44)
                ForEach(SPage.allCases) { p in
                    let on = (sel ?? .toggles) == p
                    HStack(spacing: 9) {
                        Image(systemName: p.symbol).font(.system(size: 13, weight: .medium))
                            .foregroundStyle(on ? Color.accentColor : Color.secondary).frame(width: 18)
                        Text(p.rawValue).font(.system(size: 13, weight: on ? .semibold : .regular))
                        Spacer()
                    }
                    .padding(.horizontal, 10).frame(height: 32)
                    .background { if on { Capsule().fill(Color.primary.opacity(0.1)) } }
                }
                Spacer()
            }
            .padding(.horizontal, 10).frame(width: 200)
            .background(Color.primary.opacity(0.05))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text((sel ?? .toggles).rawValue).font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 12)
                VStack(alignment: .leading, spacing: 16) {
                    switch sel ?? .toggles {
                    case .toggles: togglesPage
                    case .keepAwake: KeepAwakePageView()
                    case .permissions: PermissionsPageView()
                    default: Text("General").font(.title3)
                    }
                }.padding(.horizontal, 22)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: 840, height: 700)
        .ignoresSafeArea()
    }

    var togglesPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Card {
                FormRow("Default view", detail: "Remembered per user. You can still switch from the panel header.") {
                    Picker("", selection: .constant(Mode.grid)) {
                        Label("Grid", systemImage: "square.grid.2x2").tag(Mode.grid)
                        Label("List", systemImage: "list.bullet").tag(Mode.list)
                    }.pickerStyle(.segmented).frame(width: 150).labelsHidden()
                }
            }
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Order and visibility").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 4)
                    OrderList()
                    Text("Drag to reorder. Uncheck to hide. 3 hidden.").font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 4)
                    HStack { Button("Move Up") {}; Button("Move Down") {}; Spacer(); Button("Restore Default") {} }.controlSize(.small)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 4)
                    if let p = preview {
                        Image(nsImage: p).resizable().scaledToFit().frame(width: 230)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Text("Updates as you reorder or hide.").font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 4)
                }
            }
        }
    }
}

// MARK: B — one scrolling form

struct Chip: View {
    let text: String; var on = true; var isDefault = false
    var body: some View {
        HStack(spacing: 4) {
            if isDefault { Image(systemName: "star.fill").font(.system(size: 8)) }
            Text(text).font(.system(size: 11.5, weight: .medium)).lineLimit(1).fixedSize()
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundStyle(on ? Color.white : Color.secondary)
        .background(Capsule().fill(on ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.1))))
    }
}

struct SettingsB: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Card("Panel") {
                FormRow("Default view") {
                    Picker("", selection: .constant(Mode.grid)) {
                        Text("Grid").tag(Mode.grid); Text("List").tag(Mode.list)
                    }.pickerStyle(.segmented).frame(width: 130).labelsHidden()
                }
                Divider().padding(.leading, 12)
                FormRow("Launch at Login") { Toggle("", isOn: .constant(true)).toggleStyle(.switch).labelsHidden() }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Toggles").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 4)
                OrderList()
                Text("Drag to reorder. Uncheck to hide. 3 hidden.").font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 4)
            }
            Card("Keep Awake") {
                FormRow("Menu durations", detail: "Tap to show or hide. Star marks the default.") {
                    HStack(spacing: 5) {
                        Chip(text: "15m"); Chip(text: "30m", on: false); Chip(text: "1h", isDefault: true)
                        Chip(text: "2h"); Chip(text: "5h"); Chip(text: "∞")
                    }
                }
                Divider().padding(.leading, 12)
                FormRow("Prevent") {
                    Picker("", selection: .constant(2)) {
                        Text("System").tag(0); Text("Display").tag(1); Text("Both").tag(2)
                    }.pickerStyle(.segmented).frame(width: 190).labelsHidden()
                }
            }
            Card("Permissions") {
                FormRow("Accessibility", detail: "Do Not Disturb") { Pill(text: "Granted", color: .green) }
                Divider().padding(.leading, 12)
                FormRow("Automation", detail: "Dark Mode, Dock") {
                    HStack(spacing: 8) { Pill(text: "Needs approval", color: .orange); Button("Open Settings") {}.controlSize(.small) }
                }
            }
            HStack { Text("Toggle").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button("Check for Updates") {}.controlSize(.small) }
                .padding(.horizontal, 4)
        }
        .padding(22).frame(width: 560)
    }
}

struct PageC: View {
    let inner: AnyView
    var body: some View { inner.padding(20).frame(width: 560, alignment: .topLeading) }
}
