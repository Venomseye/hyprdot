#!/usr/bin/env bash
# btop follows the matugen theme (dot-theme init), and every `kitty --class=dot-*` launcher has a
# float rule in hypr/rules.lua.
#   bash tests/test_btop_theme.sh
set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
run() { HOME="$T" XDG_CONFIG_HOME="$T/cfg" PATH="/usr/bin:/bin" bash "$repo/bin/dot-theme" "$@" 2>&1; }
conf="$T/cfg/btop/btop.conf"

echo "--- fresh machine (no btop.conf)"
out="$(run init)"
check "init creates btop.conf with the matugen theme"       'grep -qx "color_theme = \"matugen\"" "$conf"'
check "init turns theme_background off (translucent kitty)" 'grep -qx "theme_background = False" "$conf"'
check "init creates the themes directory"                   '[ -d "$T/cfg/btop/themes" ]'

echo "--- existing btop.conf keeps the user's other settings"
rm -rf "$T/cfg"; mkdir -p "$T/cfg/btop"
printf '%s\n' '#? Config file for btop' 'color_theme = "Default"' 'theme_background = True' 'update_ms = 750' 'proc_sorting = "memory"' >"$conf"
out="$(run init)"
check "color_theme replaced"                                'grep -qx "color_theme = \"matugen\"" "$conf" && ! grep -q "Default" "$conf"'
check "theme_background replaced"                           'grep -qx "theme_background = False" "$conf" && ! grep -q "= True" "$conf"'
check "other settings untouched"                            'grep -qx "update_ms = 750" "$conf" && grep -qx "proc_sorting = \"memory\"" "$conf"'
check "a backup was made"                                   '[ "$(ls "$T"/cfg/btop/btop.conf.bak-* 2>/dev/null | wc -l)" -eq 1 ]'
check "no duplicate keys"                                   '[ "$(grep -c "^color_theme" "$conf")" -eq 1 ] && [ "$(grep -c "^theme_background" "$conf")" -eq 1 ]'

echo "--- second run changes nothing"
before="$(md5sum <"$conf")"; out="$(run init)"
check "idempotent: file identical"                          '[ "$before" = "$(md5sum <"$conf")" ]'
check "idempotent: says already configured, no new backup"  'printf "%s\n" "$out" | grep -q "btop: already configured" && [ "$(ls "$T"/cfg/btop/btop.conf.bak-* | wc -l)" -eq 1 ]'

echo "--- conf without those keys gets them appended"
printf '%s\n' 'update_ms = 500' >"$conf"; run init >/dev/null
check "keys appended, existing line kept"                   'grep -qx "color_theme = \"matugen\"" "$conf" && grep -qx "theme_background = False" "$conf" && grep -qx "update_ms = 500" "$conf"'

echo "--- doctor"
rm -f "$T/cfg/btop/themes/matugen.theme"
out="$(run doctor)"
check "doctor flags a missing generated theme"              'printf "%s\n" "$out" | grep -q "matugen.theme doesn.t exist yet"'
echo "theme[main_bg]=\"\"" >"$T/cfg/btop/themes/matugen.theme"
out="$(run doctor)"
check "doctor is happy about btop once configured"          'printf "%s\n" "$out" | grep -q "btop.conf: color_theme = matugen" && ! printf "%s\n" "$out" | grep -q "btop.conf doesn.t select"'
printf 'color_theme = "Default"\n' >"$conf"
out="$(run doctor)"
check "doctor flags btop on the default theme"              'printf "%s\n" "$out" | grep -q "btop shows its default colours"'

echo "--- every --class=dot-* launcher has a float rule"
classes="$(grep -rhoE -- '--class=dot-[a-z-]+' "$repo/config" "$repo/bin" | sort -u | sed 's/--class=//')"
check "launchers pass at least one class"                   '[ -n "$classes" ]'
for c in $classes; do
    id="${c#dot-}"
    check "rules.lua floats $c"                             'grep -qE "float_tool\(\"($c|$id)\"" "$repo/config/hypr/rules.lua"'
done

echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
