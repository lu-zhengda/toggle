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
| `script/plan-release.sh` | Next `vX.Y.Z` from semver labels and stable tags |
| `script/release.sh` | Sign, notarize, and package the DMG and `Toggle.zip` |
| `script/update-cask.sh` | Idempotent Homebrew cask version, sha256, and DMG url |
| `.github/workflows/ci.yml` | macOS CI (`build-test-package` job) |
| `.github/workflows/release-on-merge.yml` | Workflow **Release on merge** |
| `.github/workflows/release-publish.yml` | Build, publish, cask bump, and post-publish verify |
| `.github/workflows/verify-release.yml` | Manual workflow **Verify published Toggle** |
| `docs/RELEASING.md` | How a labeled merge publishes a release |
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

Releases: see `docs/RELEASING.md`. A merged pull request into `main` with exactly
one `semver:*` label publishes the next version. Do not add that label unless
the pull request should ship.

## Continuous integration

- **Runner:** `macos-15` (GitHub-hosted).
- **Required status check:** job `build-test-package` in `.github/workflows/ci.yml` (workflow **CI**).
- **Triggers:** `push` to `main`, `pull_request`. No `schedule:` — Actions here are CI/CD only.
- **Actions:** every `uses:` stays pinned to a full commit SHA with a trailing `# vX.Y.Z` comment. Do not add floating `@vN` refs.
- **Concurrency:** `group: ${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`.

The `build-test-package` job runs `script/test-plan-release.sh`, `script/test-update-cask.sh`, strict-concurrency `swift build`, `swift test`, and `./build-app.sh`.

Release workflows (**Release on merge**, **Verify published Toggle**) also run on GitHub-hosted `macos-15`. Their concurrency does not cancel an in-progress run. Neither workflow is scheduled. Signing secrets are used only after a merged, exactly-one-label plan (or a manual run from `main`) selects a version.

## Contributing and workflow rules

- Every change lands via **pull request** to `main` (squash merge). Never push directly to `main`.
- To **publish a release**, add exactly one of `semver:major`, `semver:minor`, or `semver:patch` before merging into `main`. **Release on merge** bumps the latest stable `vX.Y.Z` tag (a patch on `v1.5.1` publishes `v1.5.2`). **No semver label means no release.** More than one semver label fails the plan job. Leave docs-only and CI-only pull requests unlabeled.
- **Public-repo hygiene:** PRs, issues, docs, and test fixtures must never describe anyone's private
  dev environment — no machine names, home or temp paths, or pasted local logs. Use neutral
  placeholders in examples.

## Tests

CI and local verification:

```sh
./script/test-plan-release.sh
./script/test-update-cask.sh
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
- **Release versions are stamped at package time.** `build-app.sh` writes the same
  `TOGGLE_VERSION` into `CFBundleShortVersionString` and `CFBundleVersion` (they must
  stay equal). The release workflow sets `TOGGLE_VERSION` from the planned tag and
  does not commit a version bump. There is no Sparkle feed and no appcast. In-app
  update checks compare `releases/latest` `tag_name` with the short version; they
  do not download an asset by name.

## Adding a new toggle

1. Add a `@Published var` (and an `…Available` flag if the API may be absent).
2. Add a `toggle…()` method on `SystemController`; add its read into `refresh()`.
3. Add an `IconButton` in `ContentView` with an SF Symbol and a `.help()` title.
4. If it needs a private/system API, put the bridge in its own file and guard it.

## Permissions the app relies on

Automation (System Events / Finder), Accessibility (Lock Screen keystroke, DND),
and Bluetooth. First use of each prompts the user.