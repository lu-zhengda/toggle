import SwiftUI

@main
struct ToggleApp: App {
    @StateObject private var controller = SystemController()

    var body: some Scene {
        MenuBarExtra("Toggle", systemImage: "switch.2") {
            ContentView(controller: controller)
        }
        .menuBarExtraStyle(.window)

        Window("Toggle Settings", id: "settings") {
            SettingsView(controller: controller)
        }
        .windowResizability(.contentSize)
    }
}

struct SettingsView: View {
    @ObservedObject var controller: SystemController

    private let durationOptions: [(String, Int)] = [
        ("Indefinitely", 0),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("2 hours", 120),
    ]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { controller.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }
                ))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Updates")
                        if let status = controller.updateStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(controller.isCheckingForUpdates ? "Checking…" : "Check Now") {
                        controller.checkForUpdates()
                    }
                    .disabled(controller.isCheckingForUpdates)
                    Button("Open Releases") {
                        controller.openLatestReleasePage()
                    }
                }
            }

            Section("Keep Awake") {
                Picker("Mode", selection: $controller.keepAwakeMode) {
                    ForEach(KeepAwakeMode.allCases) { mode in
                        Text("\(mode.title) (\(mode.commandEquivalent))")
                            .tag(mode)
                    }
                }

                Picker("Default tap duration", selection: $controller.defaultKeepAwakeMinutes) {
                    ForEach(durationOptions, id: \.1) { title, minutes in
                        Text(title).tag(minutes)
                    }
                }

                Text("Right-click the coffee tile for one-off timers. The main tile uses this default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions & Safety") {
                HStack {
                    Text("Bluetooth warning")
                    Spacer()
                    if controller.bluetoothWarningSuppressed {
                        Button("Re-enable") { controller.resetBluetoothWarning() }
                    } else {
                        Text("Enabled")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("System permissions")
                    Spacer()
                    Button("Accessibility") { controller.openAccessibilitySettings() }
                    Button("Automation") { controller.openAutomationSettings() }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(controller.appVersionLabel)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Toggle")
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
        .onAppear { controller.refreshSettings() }
    }
}
