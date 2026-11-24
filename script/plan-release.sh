#!/usr/bin/env bash
# Decide whether a merge (or a manual run) publishes, and which vX.Y.Z it is.
#
# TARGET_SHA     Full commit SHA to release. Must be HEAD and reachable from MAIN_REF.
# LABELS_JSON    JSON array of pull request label names (merge path).
# BUMP           major, minor, or patch (workflow_dispatch path). Overrides LABELS_JSON.
# MAIN_REF       Branch the target must be on (default origin/main).
# GH             gh executable used to look up releases (default gh).
# GITHUB_OUTPUT  Receives publish=true|false and, when publishing, tag and version.
#
# Zero semver labels publish nothing and exit 0. More than one semver label
# exits 1. A target that already carries a stable tag resumes that tag when it
# has no GitHub Release yet, and publishes nothing when it has one.
set -euo pipefail
cd "$(dirname "$0")/.."

output() {
    echo "$1=$2"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; fi
}

skip() {
    echo "$1"
    output publish false
    exit 0
}

stable_tag() { [[ "$1" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; }

release_exists() {
    "${GH:-gh}" release view "$1" --repo "${GITHUB_REPOSITORY:-lu-zhengda/toggle}" --json tagName >/dev/null 2>&1
}

bump=${BUMP:-}
if [[ -n "$bump" ]]; then
    case "$bump" in
        major|minor|patch) echo "manual release: $bump bump" ;;
        *) echo "BUMP must be major, minor, or patch" >&2; exit 1 ;;
    esac
else
    raw=${LABELS_JSON:-[]}
    if [[ -z "$raw" ]]; then raw='[]'; fi
    labels=$(printf '%s' "$raw" | jq -r 'if type == "array" then .[] elif type == "string" then . else empty end')
    semver=$(printf '%s\n' "$labels" | grep -Ex 'semver:(major|minor|patch)' || true)
    count=$(printf '%s' "$semver" | grep -c . || true)
    if (( count == 0 )); then skip "no semver label; not releasing"; fi
    if (( count > 1 )); then
        echo "::error::found $count semver labels ($(printf '%s' "$semver" | tr '\n' ' ')); need exactly one of semver:major, semver:minor, semver:patch" >&2
        exit 1
    fi
    bump=${semver#semver:}
    echo "pull request label semver:$bump"
fi

if [[ ! "${TARGET_SHA:-}" =~ ^[0-9a-f]{40}$ ]]; then
    echo "TARGET_SHA must be a full commit SHA" >&2
    exit 1
fi
target=$(git rev-parse --verify "$TARGET_SHA^{commit}")
if [[ "$(git rev-parse HEAD)" != "$target" ]]; then
    echo "refusing to plan $target; checkout is $(git rev-parse HEAD)" >&2
    exit 1
fi
main_ref=${MAIN_REF:-origin/main}
if ! git merge-base --is-ancestor "$target" "$main_ref"; then
    echo "refusing to release $target; it is not on $main_ref" >&2
    exit 1
fi

existing=
for name in $(git tag --points-at "$target" --sort=-v:refname); do
    if stable_tag "$name"; then existing=$name; break; fi
done
if [[ -n "$existing" ]]; then
    if release_exists "$existing"; then skip "$target is already released as $existing; nothing to publish"; fi
    echo "$target is tagged $existing without a GitHub Release; resuming that tag and ignoring the $bump bump"
    tag=$existing
else
    latest=
    for name in $(git tag -l --sort=-v:refname); do
        if stable_tag "$name"; then latest=$name; break; fi
    done
    if [[ -z "$latest" ]]; then
        echo "no stable vX.Y.Z tag to bump; refusing to release" >&2
        exit 1
    fi
    IFS=. read -r major minor patch <<< "${latest#v}"
    case "$bump" in
        major) tag="v$((major + 1)).0.0" ;;
        minor) tag="v$major.$((minor + 1)).0" ;;
        patch) tag="v$major.$minor.$((patch + 1))" ;;
    esac
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
        echo "tag $tag already exists on another commit; refusing to move it" >&2
        exit 1
    fi
    echo "next release $tag ($bump bump from $latest) at $target"
fi

version=${tag#v}
output publish true
output tag "$tag"
output version "$version"
