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