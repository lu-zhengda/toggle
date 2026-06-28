# AGENTS.md

Guidance for AI agents (and humans) working in this repo.

## What this is

`Toggle` is a native macOS **menu bar app** (SwiftUI `MenuBarExtra`) that provides
one-tap system switches — a OneSwitch clone. It ships as a menu-bar-only agent
(`LSUIElement`), built with Swift Package Manager and packaged into a `.app` by a
shell script (no Xcode project).

## Build / run / package

```sh
swift build -c release        # compile the executable
./build-app.sh                # package into build/Toggle.app (Info.plist, icon, ad-hoc codesign)
open build/Toggle.app         # run (appears in the menu bar, no Dock icon)
```

There is no test target. Verify changes by building, packaging, and exercising the
relevant toggle. Many toggles can be sanity-checked from the shell by running the
same command the app runs (e.g. `defaults read -g AppleInterfaceStyle`,
`networksetup -getairportpower <dev>`).

## Layout

- `Package.swift` — SPM executable target `Toggle`. Links the private framework
  `CoreBrightness` (Night Shift / True Tone) and `IOBluetooth` via `linkerSettings`.
- `Sources/Toggle/`
  - `ToggleApp.swift` — `@main`, the `MenuBarExtra` scene.
  - `ContentView.swift` — the minimal icon-grid UI + `BluetoothShape`.
  - `SystemController.swift` — `@MainActor ObservableObject` holding all switch
    state (`@Published`) and performing every action.
  - `Shell.swift` — helpers for running processes and AppleScript.
  - `NightShift.swift`, `TrueTone.swift`, `Bluetooth.swift` — bridges to system APIs.
- `build-app.sh` — assembles the `.app` bundle and generates the icon.
- `generate-icon.swift` — renders `AppIcon` (run by `build-app.sh`).

## Architecture & conventions

- `SystemController` is the single source of truth. Each switch is a `@Published`
  Bool plus a `toggle…()` method. Feature availability is exposed as
  `…Available` properties so the UI can hide unsupported tiles.
- **Never block the main thread on subprocesses.** `refresh()` reads all state on a
  detached task and publishes back via `MainActor.run`. The read helpers are marked
  `nonisolated` so they can run off-main. (This async refresh is what keeps the
  panel from lagging when it opens — don't move the reads back onto the main actor.)
- UI is data-light: `ContentView` builds `IconButton`s from controller state. No
  text labels — every button has a `.help()` tooltip; keep that invariant when
  adding tiles.

## Gotchas (read before editing)

- **There is no SF Symbol named `bluetooth`.** `Image(systemName: "bluetooth")`
  renders blank. The Bluetooth glyph is drawn by `BluetoothShape` (a vector path).
- **Private frameworks** are reached by declaring a tiny `@objc` protocol and
  `unsafeBitCast`ing a runtime-resolved class (`NightShift`, `TrueTone`), or via
  `dlsym` (`BluetoothPower`). All are guarded — features degrade to hidden/no-op if
  the API isn't present. Don't assume they exist.
- **Wi-Fi device is auto-detected** (`networksetup -listallhardwareports`) — never
  hardcode `en0`; this machine uses `en1`.
- **Do Not Disturb** has no public API; it's best-effort Control Center UI scripting
  and needs Accessibility permission. It's the most fragile toggle and may need
  per-macOS-version tweaks.
- **Bluetooth off** can disconnect the user's keyboard/mouse. `toggleBluetooth()`
  shows a confirmation listing connected devices (with a "don't warn again" pref).
  Keep that guard.
- Packaging requires `LSUIElement` true and the usage strings in `build-app.sh`'s
  Info.plist (`NSAppleEventsUsageDescription`, `NSBluetoothAlwaysUsageDescription`).

## Adding a new toggle

1. Add a `@Published var` (and an `…Available` flag if the API may be absent).
2. Add a `toggle…()` method on `SystemController`; add its read into `refresh()`.
3. Add an `IconButton` in `ContentView` with an SF Symbol and a `.help()` title.
4. If it needs a private/system API, put the bridge in its own file and guard it.

## Permissions the app relies on

Automation (System Events / Finder), Accessibility (Lock Screen keystroke, DND),
and Bluetooth. First use of each prompts the user.
