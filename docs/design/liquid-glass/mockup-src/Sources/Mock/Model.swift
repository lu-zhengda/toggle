import SwiftUI

struct Item: Identifiable, Hashable {
    let id: String
    let name: String
    let glyph: Glyph
    var isOn: Bool?            // nil = momentary action
    var value: String? = nil   // subtitle in list view
    var options: [String]? = nil
    var selected: String? = nil
    var tint: Color = .blue
    var visible = true
    static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct Section_: Identifiable { let id: String; let title: String; var items: [Item] }

enum Sample {
    static let sections: [Section_] = [
        Section_(id: "conn", title: "Connectivity", items: [
            Item(id: "wifi", name: "Wi-Fi", glyph: .symbol("wifi"), isOn: true, value: "Home 5G"),
            Item(id: "bt", name: "Bluetooth", glyph: .bluetooth, isOn: true),
            Item(id: "airdrop", name: "AirDrop", glyph: .airdrop, isOn: true, value: "Contacts Only",
                 options: ["Contacts Only", "Everyone", "Off"], selected: "Contacts Only"),
            Item(id: "airpods", name: "AirPods", glyph: .symbol("airpods"), isOn: false, value: "AirPods Pro",
                 options: ["AirPods Pro", "AirPods Max", "Beats Studio Buds"], selected: "AirPods Pro"),
        ]),
        Section_(id: "look", title: "Display & Sound", items: [
            Item(id: "dark", name: "Dark Mode", glyph: .symbol("moon.fill"), isOn: false),
            Item(id: "night", name: "Night Shift", glyph: .symbol("sun.max.fill"), isOn: false, tint: .orange),
            Item(id: "truetone", name: "True Tone", glyph: .symbol("sun.haze.fill"), isOn: true, tint: .orange),
            Item(id: "mute", name: "Mute", glyph: .symbol("speaker.wave.2.fill"), isOn: false, value: "MacBook Speakers",
                 options: ["MacBook Speakers", "Studio Display", "AirPods Pro"], selected: "MacBook Speakers"),
        ]),
        Section_(id: "focus", title: "Focus & Power", items: [
            Item(id: "awake", name: "Keep Awake", glyph: .symbol("cup.and.saucer.fill"), isOn: true, value: "1 hr left",
                 options: ["15 minutes", "30 minutes", "1 hour", "2 hours", "5 hours", "Indefinitely"], selected: "1 hour", tint: .brown),
            Item(id: "lpm", name: "Low Power Mode", glyph: .symbol("leaf.fill"), isOn: false, tint: .yellow),
            Item(id: "dnd", name: "Do Not Disturb", glyph: .symbol("moon.circle.fill"), isOn: false, tint: .indigo),
            Item(id: "stage", name: "Stage Manager", glyph: .symbol("rectangle.stack.fill"), isOn: false),
        ]),
        Section_(id: "finder", title: "Finder & Dock", items: [
            Item(id: "desk", name: "Hide Desktop Icons", glyph: .symbol("square.grid.2x2.fill"), isOn: false),
            Item(id: "hidden", name: "Hidden Files", glyph: .symbol("eye.fill"), isOn: true),
            Item(id: "ext", name: "File Extensions", glyph: .symbol("doc.badge.ellipsis"), isOn: true),
            Item(id: "dock", name: "Dock Auto-hide", glyph: .symbol("dock.arrow.down.rectangle"), isOn: false),
        ]),
    ]
    static let actions: [Item] = [
        Item(id: "saver", name: "Screen Saver", glyph: .symbol("display"), isOn: nil),
        Item(id: "lock", name: "Lock Screen", glyph: .symbol("lock.fill"), isOn: nil),
        Item(id: "sleepd", name: "Sleep Display", glyph: .symbol("moon.zzz.fill"), isOn: nil),
        Item(id: "more", name: "More", glyph: .symbol("ellipsis"), isOn: nil),
    ]
}
