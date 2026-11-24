#!/usr/bin/env bash
# Check a Toggle disk image and the app inside it.
set -euo pipefail

image=${1:?Expected a disk image}
version=${2:?Expected the release version}
mode=${3:-}
case "$mode" in
    ""|--distribution) ;;
    *) echo "usage: $0 Toggle.dmg VERSION [--distribution]" >&2; exit 2 ;;
esac

mount=$(mktemp -d)
attached=false
cleanup() {
    local status=$?
    trap - EXIT
    if $attached; then
        hdiutil detach "$mount" >/dev/null 2>&1 || hdiutil detach "$mount" -force >/dev/null 2>&1 || status=1
    fi
    rmdir "$mount" || status=1
    exit "$status"
}
trap cleanup EXIT

if [[ "$mode" == --distribution ]]; then
    codesign --verify --strict \
        -R='anchor apple generic and certificate leaf[subject.OU] = "XY7H3QGJ2T" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' \
        "$image"
    xcrun stapler validate "$image"
    assessment=$(spctl -a -vv -t open --context context:primary-signature "$image" 2>&1) || {
        printf '%s\n' "$assessment" >&2
        exit 1
    }
    printf '%s\n' "$assessment"
    printf '%s\n' "$assessment" | grep -F 'accepted' >/dev/null
fi

hdiutil attach "$image" -readonly -nobrowse -mountpoint "$mount" >/dev/null
attached=true
test "$(readlink "$mount/Applications")" = /Applications
"$(dirname "$0")/verify-app.sh" "$mount/Toggle.app" "$version" ${mode:+"$mode"}
echo "PASS disk image $version"
