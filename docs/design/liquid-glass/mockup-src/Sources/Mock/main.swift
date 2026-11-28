import AppKit
import SwiftUI

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath

enum Kind {
    case image(AnyView)
    case fitted(AnyView)                  // real window sized to its content
    case sized(AnyView, CGSize)           // real window, fixed size
    case tabs(Int)                        // round-1 style tabbed Settings, selected tab index
}
struct Shot { let name: String; let dark: Bool; let kind: Kind }

@MainActor func makeShots() -> [Shot] {
    func g<V: View>(_ n: String, _ v: V) -> [Shot] {
        [Shot(name: "grid-\(n)-light", dark: false, kind: .image(AnyView(Framed { v }))),
         Shot(name: "grid-\(n)-dark", dark: true, kind: .image(AnyView(Framed { v })))]
    }
    var out: [Shot] = []
    out += g("A", GridA()); out += g("B", GridB()); out += g("C", GridC())
    let sz = CGSize(width: 840, height: 700)
    out += [
        Shot(name: "settings-A-sidebar-toggles-light", dark: false, kind: .sized(AnyView(SettingsA(page: .toggles)), sz)),
        Shot(name: "settings-A-sidebar-toggles-dark", dark: true, kind: .sized(AnyView(SettingsA(page: .toggles, dark: true)), sz)),
        Shot(name: "settings-A-sidebar-keepawake-light", dark: false, kind: .sized(AnyView(SettingsA(page: .keepAwake)), sz)),
        Shot(name: "settings-A-sidebar-permissions-light", dark: false, kind: .sized(AnyView(SettingsA(page: .permissions)), sz)),
        Shot(name: "settings-B-form-light", dark: false, kind: .fitted(AnyView(SettingsB()))),
        Shot(name: "settings-C-tabs-toggles-light", dark: false, kind: .tabs(1)),
        Shot(name: "settings-C-tabs-keepawake-light", dark: false, kind: .tabs(2)),
        Shot(name: "settings-C-tabs-permissions-light", dark: false, kind: .tabs(3)),
    ]
    return out
}

@MainActor func tabWindow(_ idx: Int) -> NSWindow {
    let tabs = NSTabViewController()
    tabs.tabStyle = .toolbar
    func add(_ title: String, _ sym: String, _ v: AnyView) {
        let h = NSHostingController(rootView: v)
        h.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: h)
        item.label = title; item.image = NSImage(systemSymbolName: sym, accessibilityDescription: title)
        tabs.addTabViewItem(item)
    }
    add("General", "gearshape", AnyView(PageC(inner: AnyView(Text("General").frame(height: 160)))))
    add("Toggles", "switch.2", AnyView(TogglesTab()))
    add("Keep Awake", "cup.and.saucer", AnyView(PageC(inner: AnyView(KeepAwakePageView()))))
    add("Permissions", "hand.raised", AnyView(PageC(inner: AnyView(PermissionsPageView()))))
    add("About", "info.circle", AnyView(PageC(inner: AnyView(Text("About").frame(height: 160)))))
    tabs.selectedTabViewItemIndex = idx
    let w = NSWindow(contentViewController: tabs)
    w.styleMask = [.titled, .closable]
    w.title = ["General", "Toggles", "Keep Awake", "Permissions", "About"][idx]
    w.toolbarStyle = .preference
    return w
}

final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [(Shot, NSWindow)] = []
    var shots: [Shot] = []
    @MainActor func applicationDidFinishLaunching(_ n: Notification) {
        shots = makeShots()
        var x: CGFloat = 40
        for s in shots {
            var w: NSWindow?
            switch s.kind {
            case .image: break
            case .tabs(let i): w = tabWindow(i)
            case .fitted(let v):
                let h = NSHostingController(rootView: v); h.sizingOptions = .preferredContentSize
                let win = NSWindow(contentViewController: h); win.styleMask = [.titled, .closable]; win.title = "Settings"; w = win
            case .sized(let v, let size):
                let h = NSHostingController(rootView: v)
                let win = NSWindow(contentViewController: h)
                win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                win.setContentSize(size); win.titlebarAppearsTransparent = true; win.titleVisibility = .hidden
                w = win
            }
            if let w {
                w.appearance = NSAppearance(named: s.dark ? .darkAqua : .aqua)
                w.setFrameOrigin(NSPoint(x: x, y: 60)); x += 40
                w.orderFrontRegardless()
                windows.append((s, w))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            @MainActor func prev(_ dark: Bool) -> NSImage? {
                let r = ImageRenderer(content: Framed { Panel(mode: .grid, sections: SData.visibleSections) }
                    .environment(\.colorScheme, dark ? .dark : .light))
                r.scale = 2
                guard let cg = r.cgImage else { return nil }
                return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
            }
            MainActor.assumeIsolated { PreviewStore.shared.light = prev(false)
            PreviewStore.shared.dark = prev(true) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            for (s, w) in self.windows {
                if let v = w.contentView?.superview ?? w.contentView,
                   let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(v.bounds.width * 2), pixelsHigh: Int(v.bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
                    rep.size = v.bounds.size
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: outDir + "/\(s.name).png"))
                }
            }
            for s in self.shots {
                if case .image(let v) = s.kind {
                    let r = ImageRenderer(content: v.environment(\.colorScheme, s.dark ? .dark : .light))
                    r.scale = 2
                    if let cg = r.cgImage {
                        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: outDir + "/\(s.name).png"))
                    }
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
