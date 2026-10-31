#!/usr/bin/env bash
# luasanity must catch a comma swallowed by a trailing comment, and pass the real config.
set -u
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
t="$(mktemp)"; trap 'rm -f "$t"' EXIT
printf 'hl.config({\n\ta = {\n\t\tx = 1.0   -- note,\n\t\ty = 2,\n\t},\n})\n' > "$t"
python3 tools/luasanity.py "$t" >/dev/null 2>&1 && bad "comma swallowed by a comment was not caught" || ok "comma swallowed by a comment is caught"
printf 'local f = function()\n\tlocal a = 1\n\tb = 2\nend\nhl.config({ k = f, j = 1 })\n' > "$t"
python3 tools/luasanity.py "$t" >/dev/null 2>&1 && ok "statements inside a function are not flagged" || bad "false positive inside a function body"
python3 tools/luasanity.py config/hypr/*.lua >/dev/null 2>&1 && ok "real Hyprland config is clean" || bad "real Hyprland config flagged"
# Hyprland's Lua API ignores hyprlang-style percentages in size/move rules ("60% 70%").
if grep -nE '(size|move|min_size|max_size)[[:space:]]*=[[:space:]]*"[^"]*%' config/hypr/*.lua >/dev/null; then bad "a size/move rule uses percentages (silently ignored by Hyprland)"; else ok "no percentage-style size/move rules"; fi
d="$(mktemp -d)"; mkdir -p "$d/bin"; cp -r config "$d/" 2>/dev/null; sed -i '0,/size = pct([0-9]*, [0-9]*),/s//size = "80% 85%",/' "$d/config/hypr/rules.lua"
if (cd "$d" && grep -nE '(size|move|min_size|max_size)[[:space:]]*=[[:space:]]*"[^"]*%' config/hypr/*.lua >/dev/null); then ok "the percentage check catches the old syntax"; else bad "percentage check missed the old syntax"; fi
rm -rf "$d"
echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
