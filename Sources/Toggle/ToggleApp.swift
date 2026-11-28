import SwiftUI

@main
struct ToggleApp: App {
    @StateObject private var controller = SystemController()
    @StateObject private var panel = TogglePanelModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(controller: controller, panel: panel)
                .background(PanelCorners())
        } label: {
            menuBarImage
                .accessibilityLabel(menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: controller, panel: panel)
        }
    }

    private var menuBarImage: Image {
        if controller.feedback?.isError == true { return Image(systemName: "exclamationmark.triangle.fill") }
        if controller.keepAwake { return Image(systemName: "cup.and.saucer.fill") }
        return Image(nsImage: ToggleMark.menuBarImage)
    }

    private var menuBarAccessibilityLabel: String {
        if controller.feedback?.isError == true {
            return controller.keepAwake
                ? "Toggle, action failed; Keep Awake is on"
                : "Toggle, action failed"
        }
        if controller.keepAwake { return "Toggle, Keep Awake is on" }
        return "Toggle"
    }
}
