# Toggle

A tiny native macOS menu bar app for one-tap system switches. It lives in your
menu bar, opens a compact grid of icon buttons, verifies changes against the real
system state, and reports failures instead of leaving a misleading switch behind.

<p align="center">⚙️ Dark Mode · Night Shift · True Tone · Mute · Keep Awake · Wi-Fi · Bluetooth · AirPods · Do Not Disturb · Hidden Files · and more</p>

## Features

**Toggles** (ringed with a check when on; hover any tile for its name):

- **Dark Mode** — switch appearance
- **Night Shift** / **True Tone** — display warmth (hidden or disabled when unavailable)
- **Mute** — output mute
- **Keep Awake** — prevent system sleep, display sleep, or both
  (`caffeinate -i`, `-d`, or `-i -d`); right-click for a
  15m/30m/1h/2h/indefinite timer
- **Low Power Mode** — toggle macOS Low Power Mode. macOS requires administrator
  approval, which Toggle reuses for the system's brief authorization window;
  right-click the tile to open Battery Settings without a password prompt.
- **Wi-Fi** — power the actual Wi-Fi interface via CoreWLAN (no `en0` guessing)
- **Bluetooth** — power the controller on/off (warns before disconnecting your keyboard/mouse)
- **AirPods** — quick connect/disconnect of paired AirPods
- **Do Not Disturb** — verified Focus action (best-effort Control Center scripting;
  requires Accessibility and never pretends to know the current state)
- **Hide Desktop Icons** / **Show Hidden Files** / **Show File Extensions**
- **Dock Auto-hide** — auto-hide the Dock
- **Stage Manager** — toggle Stage Manager

**Quick actions**: Screen Saver · Lock Screen · Sleep Display · More. The More
menu contains Sleep Now, Clear Clipboard, Eject All Disks, confirmed Empty Trash,
and Quit.

Every control has an explicit VoiceOver label, value, and hint. Slow system work
runs away from the main thread, the footer shows progress/results, and the menu
bar icon becomes a coffee cup while Keep Awake is active.

## Install

Via Homebrew (from a private tap):

```sh
brew install --cask lu-zhengda/tap/toggle
```

Or build from source (see below), then move `build/Toggle.app` to `/Applications`.

Open Toggle’s native Settings window (gear or ⌘,) for Launch at Login, update checks,
Keep Awake defaults, permission shortcuts, and safety options.

## Permissions

macOS gates a few toggles behind privacy approvals — click Allow on first use:

- **Automation** (System Events / Finder) — Dark Mode, Mute, Empty Trash
- **Accessibility** — Lock Screen (sends ⌃⌘Q) and Do Not Disturb
- **Bluetooth** — Bluetooth toggle and AirPods connect

Low Power Mode changes use macOS administrator authorization because the system
tool that applies them requires root access. Toggle never stores the password.

## Build from source

Requires a recent Xcode / Swift toolchain.

```sh
swift test                         # run parser/process tests
./build-app.sh                     # universal arm64 + x86_64 app
./script/build_and_run.sh --verify # rebuild, launch, verify
```

## License

MIT — see [LICENSE](LICENSE). Use at your own risk; several toggles rely on
private system frameworks and may need adjustment across macOS versions.
