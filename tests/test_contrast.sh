#!/usr/bin/env bash
# dot-contrast: fixes faint ANSI colours, leaves good ones, handles kitty + ghostty formats.
set -u
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
printf 'foreground #e0e0e0\nbackground #101418\ncolor0 #1e2428\ncolor2 #1f2a30\ncolor4 #8ed1ff\ncolor8 #1d2226\n' >"$d/kitty.conf"
printf 'background = #101418\nforeground = #e0e0e0\npalette = 2=#1f2a30\npalette = 4=#8ed1ff\n' >"$d/ghostty"
cp "$d/kitty.conf" "$d/kitty.orig"
bin/dot-contrast "$d/kitty.conf" "$d/ghostty" >/dev/null 2>&1
grep -q '^color2 #1f2a30' "$d/kitty.conf" && bad "faint kitty colour2 was not fixed" || ok "faint kitty colour2 is lightened"
grep -q '^color4 #8ed1ff' "$d/kitty.conf" && ok "good colour4 untouched" || bad "good colour4 changed"
grep -q '^color0 #1e2428' "$d/kitty.conf" && ok "colour0 untouched" || bad "colour0 changed"
grep -q '^color8 #1d2226' "$d/kitty.conf" && bad "faint colour8 not fixed" || ok "faint colour8 fixed"
grep -q 'palette = 2=#1f2a30' "$d/ghostty" && bad "ghostty palette 2 not fixed" || ok "ghostty palette is fixed too"
before="$(cat "$d/kitty.conf")"; bin/dot-contrast "$d/kitty.conf" >/dev/null 2>&1
[ "$before" = "$(cat "$d/kitty.conf")" ] && ok "second run changes nothing" || bad "not idempotent"
out="$(bin/dot-contrast --check "$d/kitty.orig" 2>&1)"
echo "$out" | grep -q 'LOW' && ok "--check reports the low colours" || bad "--check missed low colours"
cmp -s "$d/kitty.orig" "$d/kitty.conf" && bad "--check test setup" || ok "--check did not modify its file"
# light scheme: faint colours go darker
printf 'background #f8f9ff\ncolor2 #e8ecf0\n' >"$d/light"
bin/dot-contrast "$d/light" >/dev/null 2>&1; grep -q 'color2 #e8ecf0' "$d/light" && bad "light scheme not fixed" || ok "light scheme: faint colour darkened"
echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
