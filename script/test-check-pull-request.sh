#!/usr/bin/env bash
# Credential-free tests for script/check-pull-request.sh.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
command -v jq >/dev/null
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
checker="$root/script/check-pull-request.sh"
failures=0

run_check() {
  local want=$1 title=$2 body=$3 actor=${4:-human}
  local event="$work/event.json"
  jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --arg actor "$actor" \
    '{pull_request: {title: $title, body: $body}}' >"$event"
  if GITHUB_EVENT_PATH="$event" GITHUB_ACTOR="$actor" "$checker" >/dev/null 2>&1; then
    local status=0
  else
    local status=$?
  fi
  if [[ "$status" != "$want" ]]; then
    echo "FAIL: expected status $want, got $status (title=$title)" >&2
    failures=$((failures + 1))
  fi
}

good_body="$(cat <<'EOF'
## Why
Lint gates keep unsafe Swift and undocumented churn out of main.

## What changed
SwiftLint runs in CI and the PR body/title format is enforced.

## Blast Radius
CI and comments only; no runtime behavior change.

## Verification
swift test on macOS CI.

Fixes ZHE-137
EOF
)"

run_check 0 "ci(lint): example subject" "$good_body"
run_check 0 "feat: no scope" "$good_body"
run_check 1 "bad title" "$good_body"
run_check 1 "ci(lint): too long" "$(printf '%s\n' "$good_body"; seq 1 30)"
run_check 1 "ci(lint): missing section" "## Why only
Fixes ZHE-1"
run_check 0 "chore(deps): bump" "$good_body" dependabot[bot]

if (( failures > 0 )); then
  echo "$failures check(s) failed." >&2
  exit 1
fi
echo "All pull-request standard tests passed."