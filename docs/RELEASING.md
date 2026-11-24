# Releasing Toggle

## Today (manual)

Releases are cut on a Mac with signing tools installed. Distribution is a GitHub
Release asset plus a Homebrew cask in a separate repository.

1. Bump the version in `build-app.sh` (both `CFBundleVersion` and
   `CFBundleShortVersionString` — that script is the only in-tree version source).
2. Commit the bump on `main` via the normal PR flow.
3. Run `./build-app.sh`. With a **Developer ID Application** identity available, the
   script builds a **universal** (`arm64` + `x86_64`) release binary and signs
   `build/Toggle.app`. Without Developer ID, CI and local runs fall back to ad-hoc
   signing.
4. Zip the bundle the same way release assets are packaged:

   ```sh
   cd build && ditto -c -k --sequesterRsrc --keepParent Toggle.app Toggle.zip
   ```

   Confirm the stamped version, e.g. `defaults read "$PWD/Toggle.app/Contents/Info" CFBundleShortVersionString`.
5. Create the GitHub Release — tag `vX.Y.Z`, title `Toggle X.Y.Z`, asset
   `Toggle.zip`. In-app "Check for updates" uses `releases/latest` (the newest
   non-prerelease release is Latest automatically).
6. Update the Homebrew cask in [lu-zhengda/homebrew-tap](https://github.com/lu-zhengda/homebrew-tap)
   (`Casks/toggle.rb`): set `version` and `sha256` for `Toggle.zip`
   (`shasum -a 256 build/Toggle.zip`). Users install with
   `brew install --cask lu-zhengda/tap/toggle`.

Both the GitHub asset and the cask must move together — bumping one without the
other leaves `brew upgrade` or in-app updates inconsistent.

## Planned: release on merge

Release automation (not wired in this repo yet) will follow the same pattern as
[Fold](https://github.com/lu-zhengda/fold): merge a pull request into `main` that
carries exactly one semver label (`semver:major`, `semver:minor`, or
`semver:patch`). No label means the workflow succeeds without publishing.

Expected flow once workflows land:

1. **Plan** — read the semver label and compute the next `vX.Y.Z` from existing
   tags on `main`.
2. **Build** (GitHub-hosted macOS runner) — `swift test`, import signing
   credentials, run packaging (universal `Toggle.app`), **notarize** and **staple**
   the app, produce a **DMG** (and retain `Toggle.zip` or equivalent assets as
   needed), verify signatures and versions before anything is public.
3. **Publish** — create the annotated tag and GitHub Release with DMG/zip assets.
4. **Homebrew cask** — commit `toggle X.Y.Z` to `lu-zhengda/homebrew-tap`
   (`Casks/toggle.rb` version and `sha256`) using a tap token (not `GITHUB_TOKEN`).
5. **Verify published release** — download assets on a clean runner, check
   checksums, Gatekeeper/stapling, and optionally install via
   `brew install --cask lu-zhengda/tap/toggle`.

Fork pull requests will not receive signing secrets on `pull_request` events; merged
fork PRs would need a manual workflow dispatch to publish.

### Secrets (names only)

Configure under **Settings → Secrets and variables → Actions** when release
workflows exist. Values are never committed or logged.

| Secret | Role |
| --- | --- |
| `APPSTORE_API_ISSUER_ID` | App Store Connect API issuer ID for `notarytool` |
| `APPSTORE_API_KEY_ID` | App Store Connect API key ID |
| `APPSTORE_API_KEY_P8_BASE64` | Base64 of the `.p8` API key (one line) |
| `MACOS_CERT_P12_BASE64` | Base64 of the password-protected Developer ID `.p12` |
| `MACOS_CERT_PASSWORD` | Export password for that `.p12` |
| `HOMEBREW_TAP_TOKEN` | Token that can push to `lu-zhengda/homebrew-tap` |

Until those workflows exist, continue with the manual steps above.