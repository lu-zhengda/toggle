# AGENTS.md

Guidance for AI agents (and humans) working in this repo.

## What this is

`Toggle` is a native macOS **menu bar app** (SwiftUI `MenuBarExtra`) that provides
one-tap system switches. It ships as a menu-bar-only agent
(`LSUIElement`), built with Swift Package Manager and packaged into a `.app` by a
shell script (no Xcode project).

## Build / run / package

```sh
swift build -c release        # compile the executable
swift test                    # parser + subprocess reliability tests
./build-app.sh                # package into build/Toggle.app (Info.plist, icon, ad-hoc codesign)
open build/Toggle.app         # run (appears in the menu bar, no Dock icon)
./script/build_and_run.sh --verify  # rebuild, relaunch, and verify the process
```

Verify behavior changes with `swift test`, a universal packaged build, and the
relevant live toggle. Many toggles can also be sanity-checked from the shell by
running the same read command the app uses (e.g.
`defaults read -g AppleInterfaceStyle`).

## Releasing a new version

The app checks GitHub Releases for updates, and it's distributed via a Homebrew
cask in a **separate repo** (`lu-zhengda/homebrew-tap`, file `Casks/toggle.rb`).
**Both must be updated** — bumping the release without the cask leaves
`brew upgrade` users behind (and vice versa). Full flow, e.g. `X.Y.Z`:

1. Bump the version in `build-app.sh` (both `CFBundleVersion` and
   `CFBundleShortVersionString` — it's the only place the version lives).
2. Commit code + bump. End the message with the `Co-Authored-By` trailer.
3. `./build-app.sh`, then zip the bundle the same way the assets are packaged:
   `cd build && ditto -c -k --sequesterRsrc --keepParent Toggle.app Toggle.zip`
   (verify `defaults read "$PWD/Toggle.app/Contents/Info" CFBundleShortVersionString`).
4. `git push` and cut the release — tag `vX.Y.Z`, title `Toggle X.Y.Z`, asset
   `Toggle.zip`:
   `gh release create vX.Y.Z --repo lu-zhengda/toggle --title "Toggle X.Y.Z" --notes "…" build/Toggle.zip`
   (in-app "Check for updates" hits `releases/latest`, so it must be marked Latest —
   the newest non-prerelease release is, automatically).
5. Update the cask in the tap: set `version` and `sha256` (the asset's sha256 —
   `shasum -a 256 build/Toggle.zip`, or the release asset `.digest`). Commit via
   the API since the tap isn't checked out locally:
   `gh api -X PUT repos/lu-zhengda/homebrew-tap/contents/Casks/toggle.rb -f message="toggle X.Y.Z" -f sha="$(gh api repos/lu-zhengda/homebrew-tap/contents/Casks/toggle.rb --jq .sha)" -f content="$(base64 < newcask.rb)"`

## Layout

- `Package.swift` — SPM executable target `Toggle`. Links the public frameworks
  used at runtime; the private `CoreBrightness` bridge is resolved dynamically so
  unsupported systems can degrade gracefully.
- `Sources/Toggle/`
  - `ToggleApp.swift` — `@main`, the `MenuBarExtra` scene.
  - `ContentView.swift` — the minimal icon-grid UI + `BluetoothShape`.
  - `SystemController.swift` — `@MainActor ObservableObject` holding all switch
    state (`@Published`) and performing every action.
  - `Shell.swift` — helpers for running processes and AppleScript.
  - `WiFi.swift` — CoreWLAN-backed Wi-Fi power control (no interface guessing).
  - `SystemParsing.swift` — pure version/defaults/power parsers.
  - `NightShift.swift`, `TrueTone.swift`, `Bluetooth.swift` — bridges to system APIs.
- `build-app.sh` — assembles the `.app` bundle and generates the icon.
- `generate-icon.swift` — renders `AppIcon` (run by `build-app.sh`).
- `Tests/ToggleTests/` — parsers, subprocess edge cases, and a read-only refresh
  smoke test (the system-services smoke test is skipped on headless CI runners).
- `.github/workflows/ci.yml` — strict-concurrency build, tests, and universal package verification.

## Architecture & conventions

- `SystemController` is the single source of truth. Each switch is a `@Published`
  Bool plus a `toggle…()` method. Feature availability is exposed as
  `…Available` properties so the UI can hide unsupported tiles.
- **Never block the main thread on subprocesses.** `refresh()` reads all state on a
  detached task and actions use `Shell.execute`, then reconcile against the real
  state. The read helpers are marked `nonisolated` so they can run off-main. (This
  async work is what keeps the panel responsive — don't move reads or commands
  back onto the main actor.)
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
- **Wi-Fi uses CoreWLAN's current system interface** — never hardcode `en0`; this
  machine uses `en1`.
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
