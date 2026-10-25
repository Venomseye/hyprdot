#!/usr/bin/env bash
# Tests for bin/dot-sleep-log (drain maths) and the theme hook's "skip if unchanged" logic.
#   bash tests/test_sleep_and_theme.sh
set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if eval "$2"; then echo "ok    $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }

echo "--- dot-sleep-log"
export XDG_STATE_HOME="$T/state" DOT_POWER_SUPPLY_DIR="$T/ps"; mkdir -p "$T/ps/BAT0" "$T/state/dot"
w() { printf '%s\n' "$2" > "$T/ps/BAT0/$1"; }
w capacity 80; w energy_now 40000000; w status Discharging
"$repo/bin/dot-sleep-log" before; w capacity 77; w energy_now 38500000; "$repo/bin/dot-sleep-log" after
check "records before/after with battery level" 'grep -q " before 80 40000000 Discharging" "$T/state/dot/sleep.log" && grep -q " after 77 38500000 " "$T/state/dot/sleep.log"'
now=$(date +%s)
cat > "$T/state/dot/sleep.log" <<LOG
$((now-90000)) before 90 45000000 Discharging
$((now-61200)) after 66 33000000 Discharging
$((now-2000)) before 50 25000000 Charging
$((now-200)) after 58 29000000 Charging
LOG
out="$("$repo/bin/dot-sleep-log" report 5)"
check "8 h, 90% -> 66% is reported as 3.0 %/h" 'printf "%s" "$out" | grep -q "= 3.0 %/h"'
check "a charging suspend is marked not meaningful" 'printf "%s" "$out" | grep -q "charging: not meaningful"'
check "the average only uses discharging suspends" 'printf "%s" "$out" | grep -q "average over 1 suspend(s) .*: 3.0 %/h"'
rm -rf "$T/ps"; : > "$T/state/dot/sleep.log"
"$repo/bin/dot-sleep-log" before; "$repo/bin/dot-sleep-log" after
check "works without a battery (times only)" 'grep -q " before - - -" "$T/state/dot/sleep.log"'

echo "--- theme hook skips unchanged work"
export XDG_CONFIG_HOME="$T/cfg" XDG_CACHE_HOME="$T/cache" HYPRLAND_INSTANCE_SIGNATURE=x
mkdir -p "$T/bin" "$T/cfg/gtk-3.0" "$T/cfg/gtk-4.0" "$T/cfg/hypr" "$T/cfg/quickshell/theme" "$T/cache"
printf 'a{color:red}' > "$T/cfg/gtk-4.0/colors.css"; cp "$T/cfg/gtk-4.0/colors.css" "$T/cfg/gtk-3.0/"
printf 'return {primary="#fff"}' > "$T/cfg/hypr/colors-matugen.lua"
printf 'gtk-theme-name=x\ngtk-application-prefer-dark-theme=1\n' > "$T/cfg/gtk-4.0/settings.ini"; cp "$T/cfg/gtk-4.0/settings.ini" "$T/cfg/gtk-3.0/"
printf '#!/bin/sh\necho "$@" >> '"$T"'/calls\n' > "$T/bin/gsettings"
printf '#!/bin/sh\necho hyprctl "$@" >> '"$T"'/calls\n' > "$T/bin/hyprctl"; chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"
run() { : > "$T/calls"; bash "$repo/config/hooks/.d/theme-set.d/01-reload.sh" >/dev/null 2>&1; GS=$(grep -c '^set' "$T/calls"); HR=$(grep -c hyprctl "$T/calls"); }
run;                 check "first run applies GTK and reloads Hyprland" '[ "$GS" -ge 2 ] && [ "$HR" = 1 ]'
run;                 check "same colours again: nothing is touched" '[ "$GS" = 0 ] && [ "$HR" = 0 ]'
printf 'return {primary="#abc"}' > "$T/cfg/hypr/colors-matugen.lua"; printf 'a{color:blue}' > "$T/cfg/gtk-4.0/colors.css"
run;                 check "new palette applies both again" '[ "$GS" -ge 2 ] && [ "$HR" = 1 ]'
THEME_MODE=light run; check "light/dark switch re-applies even with the same colours" '[ "$GS" -ge 2 ] && [ "$HR" = 1 ]'
printf '#!/bin/sh\nexit 1\n' > "$T/bin/hyprctl"
printf 'return {primary="#999"}' > "$T/cfg/hypr/colors-matugen.lua"
run                  # this reload fails (hyprctl exits 1) and must not be remembered
printf '#!/bin/sh\necho hyprctl "$@" >> '"$T"'/calls\n' > "$T/bin/hyprctl"
run;                 check "a reload that failed is retried on the next run (failure was not remembered)" '[ "$HR" = 1 ]'

echo; echo "$pass passed, $fail failed"; [ "$fail" = 0 ]
