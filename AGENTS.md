# AGENTS.md

Guidance for AI agents (and humans) working in this repo.

## What this is

`Toggle` is a native macOS **menu bar app** (SwiftUI `MenuBarExtra`) that provides
one-tap system switches. It ships as a menu-bar-only agent
(`LSUIElement`), built with Swift Package Manager and packaged into a `.app` by a
shell script (no Xcode project).

## Repository layout

| Path | Purpose |
| --- | --- |
| `Sources/Toggle/` | App entry, UI, `SystemController`, and system bridges |
| `Tests/ToggleTests/` | Parsers, subprocess reliability, read-only smoke tests |
| `Package.swift` | SPM executable target `Toggle` |
| `build-app.sh` | Assembles universal `build/Toggle.app` and embeds the icon |
| `Assets/RockerArtwork.png` | Source artwork for the app icon |
| `generate-icon.swift` | Renders `AppIcon` (run by `build-app.sh`) |
| `script/build_and_run.sh` | Rebuild, relaunch, and verify the process |
| `.github/workflows/ci.yml` | macOS CI (`build-test-package` job) |
| `docs/RELEASING.md` | Manual release today and planned release-on-merge |
| `docs/lessons.md` | Release and CI notes |

## Build / run / package

```sh
swift build -c release        # compile the executable
swift test                    # parser + subprocess reliability tests
./build-app.sh                # package and sign build/Toggle.app (Developer ID when available)
open build/Toggle.app         # run (appears in the menu bar, no Dock icon)
./script/build_and_run.sh --verify  # rebuild, relaunch, and verify the process
```

Verify behavior changes with `swift test`, a universal packaged build, and the
relevant live toggle. Many toggles can also be sanity-checked from the shell by
running the same read command the app uses (e.g.
`defaults read -g AppleInterfaceStyle`).

Releases: see `docs/RELEASING.md` (manual today; labeled merge to `main` will drive
CI publishing once release automation lands).

## Continuous integration

- **Runner:** `macos-15` (GitHub-hosted).
- **Required status check:** job `build-test-package` in `.github/workflows/ci.yml` (workflow **CI**).
- **Triggers:** `push` to `main`, `pull_request`. No `schedule:` — Actions here are CI/CD only.
- **Actions:** every `uses:` stays pinned to a full commit SHA with a trailing `# vX.Y.Z` comment. Do not add floating `@vN` refs.
- **Concurrency:** `group: ${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`.

The `build-test-package` job runs strict-concurrency `swift build`, `swift test`, and `./build-app.sh`.

## Contributing and workflow rules

- Every change lands via **pull request** to `main` (squash merge). Never push directly to `main`.
- To **publish a new release** (once release automation exists), add exactly one label on the PR:
  `semver:major`, `semver:minor`, or `semver:patch`. Merging with that label publishes the next
  `vX.Y.Z`. **No semver label means no release** — leave docs-only and CI-only PRs unlabeled.
- **Public-repo hygiene:** PRs, issues, docs, and test fixtures must never describe anyone's private
  dev environment — no machine names, home or temp paths, or pasted local logs. Use neutral
  placeholders in examples.

## Tests

CI and local verification:

```sh
swift build
swift test
```

Optional full packaging check (macOS): `./build-app.sh` after tests pass.

## Layout (source)

- `Package.swift` — SPM executable target `Toggle`. Links the public frameworks
  used at runtime; the private `CoreBrightness` bridge is resolved dynamically so
  unsupported systems can degrade gracefully.
- `Sources/Toggle/`
  - `ToggleApp.swift` — `@main`, the `MenuBarExtra` scene.
  - `ContentView.swift` — the minimal icon-grid UI + `BluetoothShape`.
  - `SystemController.swift` — `@MainActor ObservableObject` holding all switch
    state (`@Published`) and performing every action.
  - `Shell.swift` — helpers for running processes and AppleScript.
  - `LowPowerMode.swift` — retained, invariant administrator AppleScript bridge.
  - `WiFi.swift` — CoreWLAN-backed Wi-Fi power control (no interface guessing).
  - `SystemParsing.swift` — pure version/defaults/power parsers.
  - `NightShift.swift`, `TrueTone.swift`, `Bluetooth.swift` — bridges to system APIs.
- `Tests/ToggleTests/` — parsers, subprocess edge cases, and a read-only refresh
  smoke test (the system-services smoke test is skipped on headless CI runners).

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
- **Wi-Fi uses CoreWLAN's current system interface** — never hardcode `en0` or
  guess interface names; use the API's notion of the active Wi-Fi interface.
- **Low Power Mode mutations require root.** Keep the single retained,
  parameterized `NSAppleScript` invariant so macOS can reuse its brief
  authorization cache; interpolating the state into script source causes a new
  password prompt. Never store credentials or weaken `sudoers`.
- **Do Not Disturb** has no public API; it's best-effort Control Center UI scripting
  and needs Accessibility permission. It's the most fragile toggle and may need
  per-macOS-version tweaks.
- **Bluetooth off** can disconnect the user's keyboard/mouse. `toggleBluetooth()`
  shows a confirmation listing connected devices (with a "don't warn again" pref).
  Keep that guard.
- Packaging requires `LSUIElement` true, the usage strings in `build-app.sh`'s
  Info.plist (`NSAppleEventsUsageDescription`, `NSBluetoothAlwaysUsageDescription`),
  and the Apple Events entitlement in `Toggle.entitlements`. Release builds use
  Developer ID when its signing identity is installed; CI falls back to ad-hoc signing.

## Adding a new toggle

1. Add a `@Published var` (and an `…Available` flag if the API may be absent).
2. Add a `toggle…()` method on `SystemController`; add its read into `refresh()`.
3. Add an `IconButton` in `ContentView` with an SF Symbol and a `.help()` title.
4. If it needs a private/system API, put the bridge in its own file and guard it.

## Permissions the app relies on

Automation (System Events / Finder), Accessibility (Lock Screen keystroke, DND),
and Bluetooth. First use of each prompts the user.