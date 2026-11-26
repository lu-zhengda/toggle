#!/usr/bin/env bash
# Validates pull request title and body against the repo PR standard.
set -euo pipefail

if [[ "${GITHUB_ACTOR:-}" == "dependabot[bot]" ]]; then
  echo "Skipping PR standard check for Dependabot."
  exit 0
fi

: "${GITHUB_EVENT_PATH:?GITHUB_EVENT_PATH is required}"

title=$(jq -r '.pull_request.title // empty' "$GITHUB_EVENT_PATH")
body=$(jq -r '.pull_request.body // ""' "$GITHUB_EVENT_PATH")

if [[ -z "$title" ]]; then
  echo "Missing pull request title." >&2
  exit 1
fi

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
if ! [[ "$title" =~ ^(${types})(\([a-z0-9._/-]+\))?:\ .+ ]]; then
  echo "Title must match type(scope): subject (conventional commit types)." >&2
  echo "Got: $title" >&2
  exit 1
fi

line_count=$(printf '%s' "$body" | grep -c '^' || true)
if (( line_count > 40 )); then
  echo "PR body must be at most 40 lines (got $line_count)." >&2
  exit 1
fi

for section in Why "What changed" "Blast Radius" Verification; do
  if ! grep -qiE "(^#+\s*)?${section}(\s|:|$)" <<<"$body"; then
    echo "PR body must include a '${section}' section." >&2
    exit 1
  fi
done

if ! grep -qE 'Fixes ZHE-[0-9]+' <<<"$body"; then
  echo "PR body must include a Fixes ZHE-<n> line." >&2
  exit 1
fi

echo "Pull request standard check passed."