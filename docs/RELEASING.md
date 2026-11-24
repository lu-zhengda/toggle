# Releasing Toggle

Releases are published by GitHub Actions on GitHub-hosted `macos-15` runners.
Nothing is signed or uploaded from a developer machine. The workflows follow
[lu-zhengda/fold](https://github.com/lu-zhengda/fold/blob/main/docs/RELEASING.md),
without Sparkle or an appcast.

Releases through v1.5.1 were cut by hand. The asset on those releases is
`Toggle.zip`.

## Cut a release

Add exactly one of these labels to the pull request before merging it into `main`.
The bump applies to the latest stable `vX.Y.Z` tag at merge time. Pre-release tags
are ignored. The current stable tag is `v1.5.1`, so `semver:patch` publishes `v1.5.2`.

| Label | Bump | From `v1.5.1` |
| --- | --- | --- |
| `semver:patch` | patch | `v1.5.2` |
| `semver:minor` | minor | `v1.6.0` |
| `semver:major` | major | `v2.0.0` |

- **No semver label:** the workflow succeeds without publishing. Leave docs-only and CI-only pull requests unlabeled.
- **More than one semver label:** the plan job fails and names the labels. Nothing is tagged. Publish with a manual run (see [Recovery](#recovery)).
- Other labels can sit next to the semver label and do not affect the bump.
- The version comes from the tag. `build-app.sh` stamps it into the built bundle when `TOGGLE_VERSION` is set. The workflow does not commit a version bump. Local and CI bundles that do not set `TOGGLE_VERSION` keep the fallback in `build-app.sh`.

Pull requests from forks get no secrets on `pull_request` events, so they cannot publish when merged. Merge them, then run the workflow manually from `main`.

## What runs

[`.github/workflows/release-on-merge.yml`](../.github/workflows/release-on-merge.yml) (**Release on merge**) runs when a pull request into `main` is closed, and on `workflow_dispatch` from `main`. It does not run when a pull request is opened or updated. CI's `build-test-package` job runs `script/test-plan-release.sh` and `script/test-update-cask.sh`, which need no secrets.

1. **`plan`** (`contents: read`). Skips closed pull requests that were not merged. Checks out the merge commit (or, for a manual run, `main`) with full history and tags, then runs [`script/plan-release.sh`](../script/plan-release.sh):
   - counts the semver labels (zero skips; more than one fails);
   - requires the target commit to be on `main`;
   - computes the next tag and version.

   If the commit already has a stable tag but no GitHub Release, the planner resumes that tag. If the tag already has a release, nothing is published.
2. **`release`** calls [`.github/workflows/release-publish.yml`](../.github/workflows/release-publish.yml) only when plan succeeded and chose a version. It has four jobs:
   - **`build`** (`contents: read`, signing secrets):
     - Runs `swift test`.
     - Imports the Developer ID certificate into a temporary keychain and runs [`script/release.sh`](../script/release.sh). That script runs `build-app.sh` with `TOGGLE_VERSION` set, so `CFBundleShortVersionString` and `CFBundleVersion` are both the planned `X.Y.Z`. The app is signed with Hardened Runtime, a secure timestamp, and `Toggle.entitlements`.
     - Notarizes with `xcrun notarytool submit --wait`, staples `Toggle.app`, then builds `Toggle-X.Y.Z.dmg`, signs it, and notarizes and staples it.
     - Writes `Toggle.zip` with `ditto -c -k --sequesterRsrc --keepParent` of that stapled app, and `checksums.txt` (sha256 of the DMG and the zip).
     - Before anything is published, runs `script/verify-image.sh --distribution` (`spctl -a -vv`, `xcrun stapler validate`, the Developer ID requirement, and the embedded app).
     - Uploads the three files as a workflow artifact. Deletes the keychain and key files in an `always()` step.
   - **`publish`** (`contents: write`, no signing secrets):
     - Downloads the artifact and re-checks the SHA-256.
     - Creates the annotated tag `vX.Y.Z` on the release commit, or accepts an existing tag only if it points at that commit.
     - Creates the GitHub Release `Toggle X.Y.Z`, marked latest, with `Toggle-X.Y.Z.dmg`, `Toggle.zip`, and `checksums.txt`. The notes start with the merged pull request's title and link, followed by GitHub's generated notes. The release is not a draft or prerelease.
   - **`homebrew-cask`** (`contents: read`; push uses `HOMEBREW_TAP_TOKEN`):
     - Clones [lu-zhengda/homebrew-tap](https://github.com/lu-zhengda/homebrew-tap) and runs [`script/update-cask.sh`](../script/update-cask.sh) on `Casks/toggle.rb`.
     - Sets `version`, `sha256` (the DMG), and `url` to `https://github.com/lu-zhengda/toggle/releases/download/v#{version}/Toggle-#{version}.dmg`.
     - Leaves `depends_on macos: :sonoma`, the `app "Toggle.app"` stanza, and `livecheck` (`strategy :github_latest`) in place. The edit is idempotent.
     - Commits `toggle X.Y.Z` directly to the tap's default branch. The token goes in an HTTP header that is masked and never printed.
   - **`verify-published-release`** (`contents: read`): runs `script/verify-release.sh --install-cask vX.Y.Z` on a clean runner.
     - Downloads the release assets and checks `checksums.txt`, then checks the DMG and the app inside it and the app inside `Toggle.zip` (Developer ID requirement, `xcrun stapler validate`, `spctl -a -vv`).
     - Taps `lu-zhengda/tap` fresh, checks the cask's version, sha256, and url, and runs `brew install --cask lu-zhengda/tap/toggle`.
     - Confirms the installed app is notarized, launches it, confirms the process stays up, then uninstalls the cask and confirms the app is gone.

A release created with `GITHUB_TOKEN` does not trigger `release: published`, so this verification runs inside the release workflow. [`.github/workflows/verify-release.yml`](../.github/workflows/verify-release.yml) (**Verify published Toggle**) is the same script, started only with `workflow_dispatch`. It is never scheduled.

### In-app updates

`SystemController.checkForUpdates` requests `https://api.github.com/repos/lu-zhengda/toggle/releases/latest` and decodes `tag_name`, `name`, and `html_url`. It does not read the asset list. `SystemParsing.isVersion` compares `tag_name` (`vX.Y.Z`; a leading `v` is ignored) with `CFBundleShortVersionString`.

Existing installs keep working when the new release is the latest stable release and the tag is `vX.Y.Z`. `gh release create --latest` does that, and the release is not a prerelease.

`Toggle.zip` is still uploaded under that name because every release through v1.5.1 used it (`ditto` of the app). The app does not fetch that filename. The zip is the notarized, stapled app for anyone downloading the historical asset. Homebrew installs `Toggle-X.Y.Z.dmg`; the cask's `sha256` is the DMG, and `checksums.txt` lists both files.

### Concurrency

Runs that can publish (merged pull requests with a semver label, and manual runs) share one concurrency group, `toggle-release`, with `cancel-in-progress: false`. A second merge waits. It does not cancel a run that is signing or tagging. GitHub keeps only one *pending* run per group, so if three labeled pull requests merge while a release is running, the middle one is cancelled before it starts. Publish that commit with a manual run. Closed pull requests that cannot publish use a per-run group so they never displace a pending release.

### Version

`CFBundleVersion` and `CFBundleShortVersionString` are the same `X.Y.Z` string. `build-app.sh` fails the package if they differ. There is no integer build number: Toggle does not use Sparkle. Each component must be a non-negative integer without leading zeros.

### Signing

- The `.p12` must contain exactly one code-signing identity: **Developer ID Application** for team `XY7H3QGJ2T`. The job stops if it finds anything else. `build-app.sh` signs with that identity's common name.
- The keychain is created in the runner temp directory with a random password, which is masked. The job sets it as the default keychain and the only one in the user search list, and runs `security set-key-partition-list` so `codesign` never prompts. The `always()` cleanup step deletes the keychain and the key files.
- The app is signed with Hardened Runtime, a timestamp, and `Toggle.entitlements` (Apple Events).
- The App Store Connect key is decoded to a file in the runner temp directory and passed to `notarytool --key`, `--key-id`, and `--issuer`. If a submission is not `Accepted`, the job prints `xcrun notarytool log` for it and fails. Stapling is retried, then `xcrun stapler validate` and `spctl -a -vv` must succeed for the app and the DMG.

## Secrets

Set these under **Settings → Secrets and variables → Actions** in `lu-zhengda/toggle`. Secret values are never printed. Values the workflow derives from them are masked.

| Secret | Format |
| --- | --- |
| `MACOS_CERT_P12_BASE64` | Base64 of the password-protected `.p12` holding only the Developer ID Application certificate and its private key, on one line |
| `MACOS_CERT_PASSWORD` | Export password of that `.p12` |
| `APPSTORE_API_KEY_P8_BASE64` | Base64 of `AuthKey_<KeyID>.p8` (PKCS#8 PEM), on one line |
| `APPSTORE_API_KEY_ID` | App Store Connect API key ID |
| `APPSTORE_API_ISSUER_ID` | App Store Connect issuer ID |
| `HOMEBREW_TAP_TOKEN` | Token that can push to `lu-zhengda/homebrew-tap` |

Read each value from a file or stdin so it never appears in shell history or the process list:

```sh
REPO=lu-zhengda/toggle
base64 < developer-id.p12 | tr -d '\n' | gh secret set MACOS_CERT_P12_BASE64 --repo "$REPO"
gh secret set MACOS_CERT_PASSWORD --repo "$REPO" < p12-password.txt
base64 < AuthKey_KEYID.p8 | tr -d '\n' | gh secret set APPSTORE_API_KEY_P8_BASE64 --repo "$REPO"
gh secret set APPSTORE_API_KEY_ID --repo "$REPO" < key-id.txt
gh secret set APPSTORE_API_ISSUER_ID --repo "$REPO" < issuer-id.txt
gh secret set HOMEBREW_TAP_TOKEN --repo "$REPO" < tap-token.txt
```

Delete the exported files afterwards.

## Recovery

| Situation | What to do |
| --- | --- |
| `build` failed (tests, signing, notarization, verification) | Nothing was tagged or published. Fix the cause and **Re-run failed jobs**, or merge the fix with one semver label. |
| Plan failed because of two semver labels | The event payload still has both labels, so a re-run fails the same way. **Actions → Release on merge → Run workflow** on `main`, and choose the bump. |
| `publish` failed after pushing the tag | **Re-run failed jobs**. The job accepts the tag because it points at the same commit, and deletes a draft release left by an interrupted upload. Re-running the whole workflow also works: the planner resumes the tag because it has no release yet. |
| `homebrew-cask` failed | **Re-run failed jobs**. The edit is idempotent, and the push is tried up to three times, rebasing after each rejection. |
| `verify-published-release` failed | The release and cask are already public. Read the failing check, fix forward with a new patch release if needed, then re-run the job or use **Verify published Toggle**. |
| Label forgotten, a pending run cancelled, or a fork pull request | **Actions → Release on merge → Run workflow** on `main`, and choose `patch`, `minor`, or `major`. This releases the current `main` head. |

Do not create tags, GitHub Releases, or tap commits by hand. A commit that already has a published release is never released again, and a tag on another commit is never moved.

Re-running a workflow uses the original event payload. Removing a label after the merge does not change that payload.

## Re-verify a published release

**Actions → Verify published Toggle → Run workflow**. Leave the version blank for the latest release, or enter `X.Y.Z` (or `vX.Y.Z`). The cask install is on by default and runs only on a machine with no Toggle app installed. It uninstalls the cask before the job finishes. Locally, against a release this workflow published:

```sh
./script/verify-release.sh [vX.Y.Z]
./script/verify-release.sh --install-cask   # disposable machines only
```

## Local signed builds

`script/release.sh` can exercise signing on a Mac. Set `RELEASE_VERSION` and `TOGGLE_CODESIGN_IDENTITY`, plus either `NOTARY_PROFILE` or `ASC_KEY_PATH`, `ASC_KEY_ID`, and `ASC_ISSUER_ID`. It writes `dist/Toggle-<version>.dmg`, `dist/Toggle.zip`, and `dist/checksums.txt`. Do not upload these files. Publishing goes through the workflow.

`./build-app.sh` alone still produces `build/Toggle.app` for development. Without `TOGGLE_VERSION` it stamps the fallback version. Without the Developer ID identity it ad-hoc signs, which is what CI does.
