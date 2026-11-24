#!/usr/bin/env bash
# Download a published Toggle release and check the DMG, Toggle.zip, and checksums.
# --install-cask is for a clean runner: install from the tap, launch, uninstall.
set -euo pipefail
cd "$(dirname "$0")/.."

repo=lu-zhengda/toggle
cask=lu-zhengda/tap/toggle
install=false
if [[ ${1:-} == --install-cask ]]; then
    install=true
    shift
fi
if [[ $# -gt 1 || ( $# == 1 && ! "$1" =~ ^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ) ]]; then
    echo "usage: $0 [--install-cask] [vMAJOR.MINOR.PATCH]" >&2
    exit 2
fi

work=$(mktemp -d)
installed=false
cleanup() {
    local status=$?
    trap - EXIT
    if [[ "$installed" == true ]]; then
        /usr/bin/pkill -x Toggle >/dev/null 2>&1 || true
        brew uninstall --cask toggle >/dev/null 2>&1 || true
    fi
    rm -rf "$work"
    exit "$status"
}
trap cleanup EXIT

mkdir -p "$work/assets" "$work/unzipped"
release_args=(--repo "$repo" --json 'tagName,isDraft,isPrerelease')
if [[ $# == 1 ]]; then release_args+=("v${1#v}"); fi
gh release view "${release_args[@]}" > "$work/release.json"
tag=$(jq -er 'select(.isDraft == false and .isPrerelease == false) | .tagName' "$work/release.json")
[[ "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
version=${tag#v}
image="Toggle-$version.dmg"
gh release download "$tag" --repo "$repo" --dir "$work/assets" \
    --pattern "$image" --pattern Toggle.zip --pattern checksums.txt
diff <(printf '%s\n' "$image" Toggle.zip checksums.txt | LC_ALL=C sort) \
    <(cd "$work/assets" && printf '%s\n' * | LC_ALL=C sort)
(cd "$work/assets" && shasum -a 256 -c checksums.txt)
digest=$(shasum -a 256 "$work/assets/$image" | awk '{print $1}')
grep -Fx "$digest  $image" "$work/assets/checksums.txt"
echo "PASS published $tag download and SHA-256"

xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");ToggleVerification;$(uuidgen)" "$work/assets/$image"
script/verify-image.sh "$work/assets/$image" "$version" --distribution
ditto -x -k "$work/assets/Toggle.zip" "$work/unzipped"
script/verify-app.sh "$work/unzipped/Toggle.app" "$version" --distribution
echo "PASS Toggle.zip is the notarized app"

if [[ "$install" != true ]]; then
    exit 0
fi

export XDG_CONFIG_HOME="$work/config" HOMEBREW_NO_AUTO_UPDATE=1
brew tap lu-zhengda/tap
if brew command trust >/dev/null 2>&1; then brew trust --cask "$cask"; fi
brew info --json=v2 --cask "$cask" > "$work/cask.json"
jq -e --arg v "$version" --arg sha "$digest" \
    --arg url "https://github.com/$repo/releases/download/$tag/$image" \
    '.casks[0] | .version == $v and .sha256 == $sha and .url == $url
     and any(.artifacts[]; .app == ["Toggle.app"])' "$work/cask.json" >/dev/null
cask_file="$(brew --repo lu-zhengda/homebrew-tap)/Casks/toggle.rb"
grep -Fqx '  depends_on macos: :sonoma' "$cask_file"
grep -Fqx '    strategy :github_latest' "$cask_file"
if [[ -n "$(brew list --cask --versions toggle 2>/dev/null || true)" || -e /Applications/Toggle.app ]]; then
    echo "A clean runner with no existing Toggle installation is required for --install-cask." >&2
    exit 1
fi
brew install --cask --appdir=/Applications "$cask"
installed=true
brew list --cask --versions toggle | grep -Fx "toggle $version"
script/verify-app.sh /Applications/Toggle.app "$version" --distribution

binary="/Applications/Toggle.app/Contents/MacOS/Toggle"
"$binary" >"$work/app.log" 2>&1 &
child=$!
ready=false
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    if /bin/ps -p "$child" >/dev/null 2>&1; then
        command=$(/bin/ps -p "$child" -o command= || true)
        comm=$(/bin/ps -p "$child" -o comm= || true)
        case "$command" in
            "$binary"|"$binary "*) ready=true; break ;;
        esac
        if [[ "$comm" == "$binary" ]]; then ready=true; break; fi
    fi
    sleep 0.25
done
if [[ "$ready" != true ]]; then
    echo "Toggle did not stay running from the installed app" >&2
    tail -n 40 "$work/app.log" >&2 || true
    exit 1
fi
sleep 1
if ! /bin/ps -p "$child" >/dev/null 2>&1; then
    echo "Toggle exited immediately after launch" >&2
    tail -n 40 "$work/app.log" >&2 || true
    exit 1
fi
echo "PASS Toggle is running"
kill "$child" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    /bin/ps -p "$child" >/dev/null 2>&1 || break
    sleep 0.2
done
if /bin/ps -p "$child" >/dev/null 2>&1; then
    kill -9 "$child" >/dev/null 2>&1 || true
fi

/usr/bin/pkill -x Toggle >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    /usr/bin/pgrep -x Toggle >/dev/null 2>&1 || break
    sleep 0.2
done
brew uninstall --cask toggle
test ! -e /Applications/Toggle.app
if /usr/bin/pgrep -x Toggle >/dev/null 2>&1; then
    echo "Toggle still running after uninstall" >&2
    exit 1
fi
if [[ -n "$(brew list --cask --versions toggle 2>/dev/null || true)" ]]; then
    echo "cask toggle is still installed" >&2
    exit 1
fi
installed=false
echo "PASS Homebrew install, launch, and uninstall"
