# Release and CI lessons

Each entry: **date** — what happened — what changed (or what we learned).

---

## 2026-11-24

**CI hardening and agent docs.** Concurrency on the CI workflow cancels superseded
runs on the same ref; `actions/checkout` is pinned to a full SHA (Dependabot
`github-actions` weekly keeps pins current). **Strict branch protection** means
update the PR branch before merge when `main` has moved. **An unlabeled merge does
not release** — semver labels are for the planned release-on-merge automation only.
**GitHub Actions are never scheduled** in this repo (CI/CD triggers only). **Pin
actions to SHAs**, not floating `@v` tags, so supply-chain updates are explicit PRs.

## 2026-11-24 — release on merge

**Labeled merge publishes.** The automation above is now wired. An unlabeled merge
still does not release. **More than one `semver:*` label fails the plan job**
(Fold logs a warning and skips; Toggle fails so the mistake is visible). A custom
job `if:` drops GitHub's implicit success check, so the publish job must also
require `needs.plan.result == 'success'`.

**In-app updates ignore asset names.** `checkForUpdates` reads `releases/latest`
and compares `tag_name` with `CFBundleShortVersionString`. It does not download
`Toggle.zip`. The release still uploads that filename — a `ditto` zip of the
notarized, stapled app, the asset every release through v1.5.1 used — plus
`Toggle-X.Y.Z.dmg` and `checksums.txt`. The cask sha256 is the DMG. The cask url
used to be `Toggle.zip`; the bump rewrites version, sha256, and url, and must
leave `depends_on macos: :sonoma` in place.

**Both bundle versions stay equal.** `build-app.sh` rejects a
`CFBundleVersion` that differs from `CFBundleShortVersionString`, so the planned
`X.Y.Z` is stamped into both via `TOGGLE_VERSION`. There is no Sparkle build
number and no appcast. `actions/checkout` with `fetch-depth: 0` fetches tags;
the planner needs those tags. Signing runs only on GitHub-hosted `macos-15`.
**First automated release is a patch.** v1.5.2 was cut only to prove the
pipeline end to end: plan, sign, notarize, staple, DMG, checksums, cask bump,
and the post-publish verify job. A no-code `semver:patch` PR is the cheapest
way to exercise a new release workflow before real changes depend on it.

## Lint and PR gates

| Mistake | Rule | Enforced where |
| --- | --- | --- |
| Force casts (`as!`), `try!`, or `!` unwraps that hide real failures | `force_cast`, `force_try`, `force_unwrapping` | `.swiftlint.yml` → CI `build-test-package` (`swiftlint --strict`) |
| `TODO` left in production sources | `todo` | `.swiftlint.yml` → CI `build-test-package` |
| Plain `//` comments instead of `///` or `// MARK:` | `no_plain_line_comment`, `no_plain_trailing_comment` | `.swiftlint.yml` → CI `build-test-package` |
| Assuming `swiftlint` is on `PATH` for every `macos-15` SKU | `brew install swiftlint` only when the binary is missing (Arm64 images omit it) | `.github/workflows/ci.yml` SwiftLint step |
| PR title/body that skip Why / What / blast radius / verification or omit `Fixes ZHE-*` | Conventional title + 40-line body standard | `script/check-pull-request.sh` → CI `pull-request-standard` on `opened` / `synchronize` / `edited` (Dependabot exempt) |
