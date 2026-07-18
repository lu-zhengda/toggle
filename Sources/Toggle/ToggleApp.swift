import SwiftUI

@main
struct ToggleApp: App {
    @StateObject private var controller = SystemController()

    var body: some Scene {
        MenuBarExtra {
            ContentView(controller: controller)
        } label: {
            Image(systemName: menuBarSymbol)
                .accessibilityLabel(menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(controller: controller)
        }
    }

    private var menuBarSymbol: String {
        if controller.feedback?.isError == true { return "exclamationmark.triangle.fill" }
        if controller.keepAwake { return "cup.and.saucer.fill" }
        return "switch.2"
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
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { controller.launchAtLogin },
                        set: { controller.setLaunchAtLogin($0) }
                    ))
                    if let status = controller.launchAtLoginStatus {
                        HStack {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Open Login Items") { controller.openLoginItemsSettings() }
                                .controlSize(.small)
                        }
                    }
                }

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
                        Text(mode.title).tag(mode)
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

                HStack(spacing: 8) {
                    Label("Accessibility", systemImage: controller.accessibilityGranted
                          ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text(controller.accessibilityGranted ? "Granted" : "Needed for Focus and Lock Screen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Settings") { controller.openAccessibilitySettings() }
                        .accessibilityLabel("Open Accessibility Settings")
                }

                HStack(spacing: 8) {
                    Label("Automation", systemImage: "gearshape.2.fill")
                    Text("macOS prompts when Finder or System Events is first used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Settings") { controller.openAutomationSettings() }
                        .accessibilityLabel("Open Automation Settings")
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
        .frame(width: 560)
        .onAppear {
            controller.refreshSettings()
            controller.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refreshSettings()
            controller.refresh()
        }
    }
}
