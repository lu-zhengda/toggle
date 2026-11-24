#!/usr/bin/env bash
# Build, sign, notarize, and staple Toggle.app and Toggle-X.Y.Z.dmg.
# Writes dist/Toggle-X.Y.Z.dmg, dist/Toggle.zip, and dist/checksums.txt.
#
# Requires TOGGLE_CODESIGN_IDENTITY and RELEASE_VERSION. Notarization uses
# ASC_KEY_PATH, ASC_KEY_ID, and ASC_ISSUER_ID, or NOTARY_PROFILE.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${RELEASE_VERSION:?Set RELEASE_VERSION to MAJOR.MINOR.PATCH}"
: "${TOGGLE_CODESIGN_IDENTITY:?Set TOGGLE_CODESIGN_IDENTITY to the Developer ID Application identity}"
if [[ "$TOGGLE_CODESIGN_IDENTITY" == "-" ]]; then
    echo "refusing ad-hoc signing for a release" >&2
    exit 1
fi
if [[ ! "$RELEASE_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "RELEASE_VERSION must be MAJOR.MINOR.PATCH" >&2
    exit 1
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    credentials=(--keychain-profile "$NOTARY_PROFILE")
else
    credentials=(--key "${ASC_KEY_PATH:?}" --key-id "${ASC_KEY_ID:?}" --issuer "${ASC_ISSUER_ID:?}")
fi

export TOGGLE_VERSION="$RELEASE_VERSION"
./build-app.sh
app="$PWD/build/Toggle.app"
script/verify-app.sh "$app" "$RELEASE_VERSION"

out="$PWD/dist"
rm -rf "$out"
mkdir -p "$out"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

notarize() {
    local archive=$1 target=$2 status id stapled attempt
    if ! xcrun notarytool submit "$archive" "${credentials[@]}" --wait --output-format json > "$work/result.json"; then
        echo "notarytool submit failed for $(basename "$archive")" >&2
    fi
    cat "$work/result.json"
    status=$(plutil -extract status raw "$work/result.json" 2>/dev/null || true)
    if [[ "$status" != Accepted ]]; then
        id=$(plutil -extract id raw "$work/result.json" 2>/dev/null || true)
        if [[ -n "$id" ]]; then xcrun notarytool log "$id" "${credentials[@]}" >&2 || true; fi
        return 1
    fi
    stapled=false
    for attempt in 1 2 3 4 5; do
        if xcrun stapler staple "$target"; then
            stapled=true
            break
        fi
        echo "stapler attempt $attempt failed; retrying" >&2
        sleep 10
    done
    if [[ "$stapled" != true ]]; then
        echo "could not staple $target" >&2
        return 1
    fi
    xcrun stapler validate "$target"
}

# Apple accepts a zip of the signed app. This zip is not a release asset.
ditto -c -k --keepParent "$app" "$work/Toggle-notarize.zip"
notarize "$work/Toggle-notarize.zip" "$app"
script/verify-app.sh "$app" "$RELEASE_VERSION" --distribution

image="Toggle-$RELEASE_VERSION.dmg"
image_root="$work/image"
mkdir -p "$image_root"
ditto "$app" "$image_root/Toggle.app"
ln -s /Applications "$image_root/Applications"
hdiutil create -volname Toggle -srcfolder "$image_root" -fs HFS+ -format UDZO "$work/$image" >/dev/null
codesign --timestamp --sign "$TOGGLE_CODESIGN_IDENTITY" "$work/$image"
codesign --verify --strict "$work/$image"
notarize "$work/$image" "$work/$image"
script/verify-image.sh "$work/$image" "$RELEASE_VERSION" --distribution

# Same packaging command releases through v1.5.1 used for Toggle.zip.
# The app inside is already notarized and stapled.
ditto -c -k --sequesterRsrc --keepParent "$app" "$work/Toggle.zip"
(
    cd "$work"
    shasum -a 256 "$image" Toggle.zip | LC_ALL=C sort -k2 > checksums.txt
)
digest=$(shasum -a 256 "$work/$image" | awk '{print $1}')
grep -Fx "$digest  $image" "$work/checksums.txt"
mv "$work/$image" "$work/Toggle.zip" "$work/checksums.txt" "$out/"
diff <(printf '%s\n' "$image" Toggle.zip checksums.txt | LC_ALL=C sort) <(cd "$out" && printf '%s\n' * | LC_ALL=C sort)
(cd "$out" && shasum -a 256 -c checksums.txt)
echo "PASS release assets $RELEASE_VERSION"
