#!/usr/bin/env bash
# Check one Toggle.app. --distribution also requires the Developer ID,
# the notarization staple, and a Gatekeeper accept.
set -euo pipefail

app=${1:?Expected the path to Toggle.app}
version=${2:?Expected the release version}
mode=${3:-}
case "$mode" in
    ""|--distribution) ;;
    *) echo "usage: $0 Toggle.app VERSION [--distribution]" >&2; exit 2 ;;
esac
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "version must be MAJOR.MINOR.PATCH" >&2
    exit 2
fi

plist="$app/Contents/Info.plist"
plutil -lint "$plist" >/dev/null
value() { plutil -extract "$1" raw "$plist"; }

expect() {
    if [[ "$1" != "$2" ]]; then
        echo "expected $3 to be '$2', got '$1'" >&2
        exit 1
    fi
}

expect "$(value CFBundleIdentifier)" com.zhengdalu.toggle CFBundleIdentifier
expect "$(value CFBundleShortVersionString)" "$version" CFBundleShortVersionString
expect "$(value CFBundleVersion)" "$version" CFBundleVersion
expect "$(value CFBundleExecutable)" Toggle CFBundleExecutable
expect "$(value LSUIElement)" true LSUIElement
expect "$(value LSMinimumSystemVersion)" 14.0 LSMinimumSystemVersion
expect "$(value CFBundleIconFile)" AppIcon CFBundleIconFile
test -s "$app/Contents/Resources/AppIcon.icns"

exe="$app/Contents/MacOS/Toggle"
test -x "$exe"
for arch in arm64 x86_64; do
    lipo "$exe" -verify_arch "$arch"
done
codesign --verify --deep --strict --verbose=2 "$app"

if [[ "$mode" == --distribution ]]; then
    codesign --verify --strict --all-architectures \
        -R='anchor apple generic and identifier "com.zhengdalu.toggle" and certificate leaf[subject.OU] = "XY7H3QGJ2T" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' \
        "$app"
    entitlements=$(codesign -d --entitlements :- "$app" 2>/dev/null || true)
    printf '%s\n' "$entitlements" | grep -q 'com.apple.security.automation.apple-events'
    signature=$(codesign -dv "$app" 2>&1 || true)
    printf '%s\n' "$signature" | grep -q 'runtime'
    xcrun stapler validate "$app"
    assessment=$(spctl -a -vv -t execute "$app" 2>&1) || {
        printf '%s\n' "$assessment" >&2
        exit 1
    }
    printf '%s\n' "$assessment"
    printf '%s\n' "$assessment" | grep -Fqx 'source=Notarized Developer ID'
fi

echo "PASS Toggle.app $version"
