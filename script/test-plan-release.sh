#!/usr/bin/env bash
# Credential-free checks for script/plan-release.sh against a throwaway repository.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
command -v jq >/dev/null
command -v git >/dev/null
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
repo="$work/repo"
mkdir -p "$repo/script"
cp "$root/script/plan-release.sh" "$repo/script/"
# Stand-in for `gh release view`: a tag has a release when it is listed in $work/released.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\ngrep -Fqx "$3" "%s/released"\n' "$work" > "$work/gh"
chmod +x "$work/gh"
: > "$work/released"
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
git -C "$repo" tag v1.0.0
git -C "$repo" tag v1.1.0
git -C "$repo" tag v2.0.0-beta.1
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m two
head=$(git -C "$repo" rev-parse HEAD)
failures=0

plan() {
    : > "$work/out"
    (cd "$repo" && env -u BUMP -u LABELS_JSON -u GITHUB_REPOSITORY \
        MAIN_REF=main GH="$work/gh" GITHUB_OUTPUT="$work/out" \
        TARGET_SHA="$head" "$@" script/plan-release.sh) > "$work/log" 2>&1
}

check() {
    local name=$1 want_status=$2 want_out=$3 status=0
    shift 3
    plan "$@" || status=$?
    local got
    got=$(tr '\n' ' ' < "$work/out")
    if [[ "$status" != "$want_status" || "$got" != "$want_out" ]]; then
        echo "FAIL $name: status $status, outputs '$got'" >&2
        sed 's/^/    /' "$work/log" >&2
        failures=$((failures + 1))
        return
    fi
    if [[ "$name" == *"semver labels"* ]] && ! grep -q 'exactly one' "$work/log"; then
        echo "FAIL $name: expected a clear exactly-one error" >&2
        sed 's/^/    /' "$work/log" >&2
        failures=$((failures + 1))
    fi
}

check "no labels" 0 "publish=false " LABELS_JSON='[]'
check "empty labels" 0 "publish=false " LABELS_JSON=
check "no pull request" 0 "publish=false " LABELS_JSON=null
check "unrelated labels" 0 "publish=false " LABELS_JSON='["docs","semver:huge"]'
check "two semver labels" 1 "" LABELS_JSON='["semver:minor","semver:patch"]'
check "three semver labels" 1 "" LABELS_JSON='["semver:major","semver:minor","semver:patch"]'
check "patch label" 0 "publish=true tag=v1.1.1 version=1.1.1 " LABELS_JSON='["bug","semver:patch"]'
check "patch label as string" 0 "publish=true tag=v1.1.1 version=1.1.1 " LABELS_JSON='"semver:patch"'
check "minor label" 0 "publish=true tag=v1.2.0 version=1.2.0 " LABELS_JSON='["semver:minor"]'
check "major label" 0 "publish=true tag=v2.0.0 version=2.0.0 " LABELS_JSON='["semver:major"]'
check "manual bump" 0 "publish=true tag=v1.1.1 version=1.1.1 " BUMP=patch LABELS_JSON='["semver:major"]'
check "bad manual bump" 1 "" BUMP=huge
check "short sha" 1 "" BUMP=patch TARGET_SHA="${head:0:12}"
check "not HEAD" 1 "" BUMP=patch TARGET_SHA="$(git -C "$repo" rev-parse HEAD~1)"

git -C "$repo" tag v1.2.0
check "resume unreleased tag" 0 "publish=true tag=v1.2.0 version=1.2.0 " BUMP=major
echo v1.2.0 >> "$work/released"
check "already released" 0 "publish=false " LABELS_JSON='["semver:minor"]'
git -C "$repo" tag -d v1.2.0 >/dev/null

git -C "$repo" tag v1.9.4 HEAD~1
check "highest tag, not newest commit" 0 "publish=true tag=v1.10.0 version=1.10.0 " LABELS_JSON='["semver:minor"]'
git -C "$repo" tag v1.999.0 HEAD~1
check "large component" 0 "publish=true tag=v1.1000.0 version=1.1000.0 " BUMP=minor
git -C "$repo" tag -d v1.999.0 >/dev/null

git -C "$repo" checkout -q -b side
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m side
head=$(git -C "$repo" rev-parse HEAD)
check "not on main" 1 "" BUMP=patch

if (( failures > 0 )); then exit 1; fi
echo "PASS release planning"
