import SwiftUI

@main
struct ToggleApp: App {
    @StateObject private var controller = SystemController()

    var body: some Scene {
        MenuBarExtra("Toggle", systemImage: "switch.2") {
            ContentView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}
