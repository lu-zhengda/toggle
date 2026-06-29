# Toggle

A tiny native macOS menu bar app for one-tap system switches. Lives in your menu
bar, opens a compact grid of icon buttons, and flips system state instantly.

<p align="center">⚙️ Dark Mode · Night Shift · True Tone · Mute · Keep Awake · Wi-Fi · Bluetooth · AirPods · Do Not Disturb · Hidden Files · and more</p>

## Features

**Toggles** (lit when on; hover any tile for its name):

- **Dark Mode** — switch appearance
- **Night Shift** / **True Tone** — display warmth (hidden if your display lacks them)
- **Mute** — output mute
- **Keep Awake** — prevent system sleep (`caffeinate -i`); right-click for a 15m/30m/1h/2h/indefinite timer
- **Wi-Fi** — power the Wi-Fi interface on/off
- **Bluetooth** — power the controller on/off (warns before disconnecting your keyboard/mouse)
- **AirPods** — quick connect/disconnect of paired AirPods
- **Do Not Disturb** — toggle Focus (best-effort; requires Accessibility)
- **Hide Desktop Icons** / **Show Hidden Files** / **Show File Extensions**
- **Dock Auto-hide** — auto-hide the Dock
- **Stage Manager** — toggle Stage Manager

**Actions**: Screen Saver · Lock Screen · Sleep Display · Sleep Now · Empty Trash · Clear Clipboard · Eject All Disks

## Install

Via Homebrew (from a private tap):

```sh
brew install --cask lu-zhengda/tap/toggle
```

Or build from source (see below), then move `build/Toggle.app` to `/Applications`.

To launch at login: System Settings → General → Login Items → add Toggle.

## Permissions

macOS gates a few toggles behind privacy approvals — click Allow on first use:

- **Automation** (System Events / Finder) — Dark Mode, Mute, Empty Trash
- **Accessibility** — Lock Screen (sends ⌃⌘Q) and Do Not Disturb
- **Bluetooth** — Bluetooth toggle and AirPods connect

## Build from source

Requires a recent Xcode / Swift toolchain.

```sh
swift build -c release   # compile
./build-app.sh           # package into build/Toggle.app (menu-bar-only, ad-hoc signed, with icon)
open build/Toggle.app
```

## License

MIT — see [LICENSE](LICENSE). Use at your own risk; several toggles rely on
private system frameworks and may need adjustment across macOS versions.
