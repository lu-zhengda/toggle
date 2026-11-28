import AppKit
import SwiftUI

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath

struct Shot { let name: String; let dark: Bool; let view: AnyView; let settings: Bool }

let shots: [Shot] = [
    Shot(name: "01-grid-light", dark: false, view: AnyView(Scene_(mode: .grid)), settings: false),
    Shot(name: "02-grid-dark", dark: true, view: AnyView(Scene_(mode: .grid)), settings: false),
    Shot(name: "03-list-light", dark: false, view: AnyView(Scene_(mode: .list)), settings: false),
    Shot(name: "04-list-dark", dark: true, view: AnyView(Scene_(mode: .list)), settings: false),
    Shot(name: "05-list-keepawake-dropdown-light", dark: false, view: AnyView(Scene_(mode: .list, expandedID: "awake", sections: [Sample.sections[2]])), settings: false),
    Shot(name: "05b-list-airdrop-dropdown-dark", dark: true, view: AnyView(Scene_(mode: .list, expandedID: "airdrop", sections: [Sample.sections[0]])), settings: false),
    Shot(name: "06-settings-toggles-light", dark: false, view: AnyView(TogglesTab()), settings: true),
    Shot(name: "07-settings-toggles-dark", dark: true, view: AnyView(TogglesTab()), settings: true),
    Shot(name: "07b-settings-mid-drag-light", dark: false, view: AnyView(TogglesTab(dragging: true)), settings: true),
]

final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ n: Notification) {
        var x: CGFloat = 40
        var lines: [String] = []
        for s in shots {
            let w: NSWindow
            if s.settings {
                let tabs = NSTabViewController()
                tabs.tabStyle = .toolbar
                func add(_ title: String, _ sym: String, _ v: AnyView) {
                    let h = NSHostingController(rootView: v)
                    h.sizingOptions = .preferredContentSize
                    let item = NSTabViewItem(viewController: h)
                    item.label = title; item.image = NSImage(systemSymbolName: sym, accessibilityDescription: title)
                    tabs.addTabViewItem(item)
                }
                add("General", "gearshape", AnyView(PlaceholderTab(title: "General")))
                add("Toggles", "switch.2", s.view)
                add("Keep Awake", "cup.and.saucer", AnyView(PlaceholderTab(title: "Keep Awake")))
                add("Permissions", "hand.raised", AnyView(PlaceholderTab(title: "Permissions")))
                add("About", "info.circle", AnyView(PlaceholderTab(title: "About")))
                tabs.selectedTabViewItemIndex = 1
                w = NSWindow(contentViewController: tabs)
                w.styleMask = [.titled, .closable]
                w.title = "Toggles"
                w.toolbarStyle = .preference
            } else {
                let h = NSHostingView(rootView: s.view)
                h.frame.size = h.fittingSize
                w = NSWindow(contentRect: NSRect(origin: .zero, size: h.fittingSize),
                             styleMask: [.borderless], backing: .buffered, defer: false)
                w.contentView = h
            }
            w.appearance = NSAppearance(named: s.dark ? .darkAqua : .aqua)
            w.setFrameOrigin(NSPoint(x: x, y: 60))
            x += 60
            w.orderFrontRegardless()
            windows.append(w)
            lines.append("\(s.name) \(w.windowNumber)")
        }
        try? lines.joined(separator: "\n").write(toFile: outDir + "/windows.txt", atomically: true, encoding: .utf8)
        // Offscreen fallbacks: cacheDisplay of the live window view, and ImageRenderer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            for (s, w) in zip(shots, self.windows) {
                if s.settings, let v = w.contentView?.superview ?? w.contentView,
                   let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(v.bounds.width * 2), pixelsHigh: Int(v.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
                    rep.size = v.bounds.size
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: outDir + "/cache-\(s.name).png"))
                }
                let r = ImageRenderer(content: s.view.environment(\.colorScheme, s.dark ? .dark : .light))
                r.scale = 2
                if let cg = r.cgImage {
                    let rep = NSBitmapImageRep(cgImage: cg)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: outDir + "/ir-\(s.name).png"))
                }
            }
            try? "done".write(toFile: outDir + "/ready.txt", atomically: true, encoding: .utf8)
        }
    }
}

let app = NSApplication.shared
let d = Delegate()
app.delegate = d
app.setActivationPolicy(.accessory)
app.run()
