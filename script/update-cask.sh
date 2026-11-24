#!/usr/bin/env bash
# Point Casks/toggle.rb at one Toggle DMG release.
#
# Rewrites the single version, sha256, and url lines. Leaves depends_on
# macos: :sonoma, the app stanza, livecheck, and every other line alone.
# Exits 0 and prints "unchanged" when those three lines already match, or
# "updated" after editing. Does not commit.
set -euo pipefail

cask=${1:?cask path}
version=${2:?version}
sha=${3:?sha256}
url_line='  url "https://github.com/lu-zhengda/toggle/releases/download/v#{version}/Toggle-#{version}.dmg"'

if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "version must be MAJOR.MINOR.PATCH" >&2
    exit 1
fi
if [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]]; then
    echo "sha256 must be 64 lowercase hex characters" >&2
    exit 1
fi
if [[ ! -f "$cask" ]]; then
    echo "cask not found: $cask" >&2
    exit 1
fi

backup=$(mktemp)
tmp=$(mktemp)
trap 'rm -f "$backup" "$tmp"' EXIT
cp "$cask" "$backup"

version_count=0
sha_count=0
url_count=0
while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
        '  version "'*)
            version_count=$((version_count + 1))
            printf '  version "%s"\n' "$version"
            ;;
        '  sha256 "'*)
            sha_count=$((sha_count + 1))
            printf '  sha256 "%s"\n' "$sha"
            ;;
        '  url "'*)
            url_count=$((url_count + 1))
            printf '%s\n' "$url_line"
            ;;
        *)
            printf '%s\n' "$line"
            ;;
    esac
done < "$cask" > "$tmp"

if [[ "$version_count" != 1 || "$sha_count" != 1 || "$url_count" != 1 ]]; then
    echo "$cask must have exactly one version line, one sha256 line, and one url line" >&2
    exit 1
fi

require_line() {
    if ! grep -Fqx "$1" "$tmp"; then
        echo "cask is missing: $1" >&2
        exit 1
    fi
}
require_line "  version \"$version\""
require_line "  sha256 \"$sha\""
require_line "$url_line"
require_line '  depends_on macos: :sonoma'
require_line '  app "Toggle.app"'
require_line '    url :url'
require_line '    strategy :github_latest'

mv "$tmp" "$cask"
if cmp -s "$backup" "$cask"; then
    echo unchanged
else
    echo updated
fi
