#!/usr/bin/env bash
# Credential-free checks for script/update-cask.sh.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
if grep -q tahoe "$root/script/update-cask.sh"; then
    echo "update-cask.sh must keep Sonoma and must not retarget the cask" >&2
    exit 1
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
new_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
other_sha=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

write_cask() {
    cat > "$1" <<'CASK'
cask "toggle" do
  version "1.5.1"
  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  url "https://github.com/lu-zhengda/toggle/releases/download/v#{version}/Toggle.zip"
  name "Toggle"
  desc "Menu bar app for one-tap system switches"
  homepage "https://github.com/lu-zhengda/toggle"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Toggle.app"

  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{staged_path}}/Toggle.app"]
  end
end
CASK
}

cask="$work/toggle.rb"
write_cask "$cask"
original=$(cat "$cask")
status=$("$root/script/update-cask.sh" "$cask" 1.5.2 "$new_sha")
[[ "$status" == updated ]]
grep -Fqx '  version "1.5.2"' "$cask"
grep -Fqx "  sha256 \"$new_sha\"" "$cask"
grep -Fqx '  url "https://github.com/lu-zhengda/toggle/releases/download/v#{version}/Toggle-#{version}.dmg"' "$cask"
grep -Fqx '  depends_on macos: :sonoma' "$cask"
grep -Fqx '  app "Toggle.app"' "$cask"
grep -Fqx '    strategy :github_latest' "$cask"
grep -Fqx '  desc "Menu bar app for one-tap system switches"' "$cask"
grep -Fqx '    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{staged_path}}/Toggle.app"]' "$cask"
if grep -q 'Toggle.zip' "$cask"; then
    echo "zip url remained after the bump" >&2
    exit 1
fi

again=$("$root/script/update-cask.sh" "$cask" 1.5.2 "$new_sha")
[[ "$again" == unchanged ]]

third=$("$root/script/update-cask.sh" "$cask" 1.5.2 "$other_sha")
[[ "$third" == updated ]]
grep -Fqx "  sha256 \"$other_sha\"" "$cask"
grep -Fqx '  url "https://github.com/lu-zhengda/toggle/releases/download/v#{version}/Toggle-#{version}.dmg"' "$cask"

write_cask "$cask"
if "$root/script/update-cask.sh" "$cask" 1.5.2 abc >"$work/bad" 2>&1; then
    echo "short sha256 was accepted" >&2
    exit 1
fi
[[ "$(cat "$cask")" == "$original" ]]

sed '/depends_on macos/d' "$cask" > "$work/no-sonoma.rb"
if "$root/script/update-cask.sh" "$work/no-sonoma.rb" 1.5.2 "$new_sha" >"$work/bad" 2>&1; then
    echo "missing Sonoma dependency was accepted" >&2
    exit 1
fi

printf '%s\n' '  version "1.0.0"' '  version "1.0.1"' '  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' '  url "https://example.invalid/Toggle.zip"' '  depends_on macos: :sonoma' '  app "Toggle.app"' '    url :url' '    strategy :github_latest' > "$work/two.rb"
if "$root/script/update-cask.sh" "$work/two.rb" 1.5.2 "$new_sha" >"$work/bad" 2>&1; then
    echo "two version lines were accepted" >&2
    exit 1
fi

echo "PASS cask update"
