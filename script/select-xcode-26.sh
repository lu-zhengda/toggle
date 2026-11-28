#!/bin/bash
# Select the newest stable Xcode 26 so Liquid Glass compiles into the binary.
set -euo pipefail

key_for() {
  local name="${1#Xcode_}"
  name="${name%.app}"
  local major=0 minor=0 patch=0
  IFS=. read -r major minor patch <<<"$name"
  printf '%03d%03d%03d' "${major:-0}" "${minor:-0}" "${patch:-0}"
}

best=""
best_key=""
consider() {
  local app="$1"
  local key="$2"
  if [[ -z "$best_key" || "$key" > "$best_key" ]]; then
    best="$app"
    best_key="$key"
  fi
}

shopt -s nullglob
for app in /Applications/Xcode_26*.app /Applications/Xcode.app; do
  [[ -d "$app/Contents/Developer" ]] || continue
  base="$(basename "$app")"
  lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *beta*|*rc*) continue ;;
  esac
  if [[ "$base" == Xcode_26* ]]; then
    consider "$app" "$(key_for "$base")"
    continue
  fi
  version="$(
    "$app/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | awk 'NR==1 { print $2 }' || true
  )"
  case "$version" in
    26*) consider "$app" "$(key_for "Xcode_$version")" ;;
  esac
done

if [[ -z "$best" ]]; then
  echo "Xcode 26 is required and was not found" >&2
  exit 1
fi

sudo xcode-select -s "$best/Contents/Developer"
echo "Selected $best"
xcodebuild -version
