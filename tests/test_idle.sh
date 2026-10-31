#!/usr/bin/env bash
# dot-power idle-suspend: battery vs mains, the idle-action word, hibernate fallback.
set -u
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
mkdir -p "$d/bin" "$d/ps/BAT0" "$d/ps/AC" "$d/cfg/hypr"
printf '#!/bin/sh\nif [ "$1" = can-hibernate ]; then echo "${CAN_HIB:-no}"; exit 0; fi\necho "$@" >> "%s/calls"\n' "$d" >"$d/bin/systemctl"; chmod +x "$d/bin/systemctl"
echo Battery >"$d/ps/BAT0/type"; echo Mains >"$d/ps/AC/type"
run() { : >"$d/calls"; PATH="$d/bin:/usr/bin:/bin" DOT_POWER_SUPPLY_DIR="$d/ps" XDG_CONFIG_HOME="$d/cfg" bash bin/dot-power idle-suspend "$@" >/dev/null 2>&1; cat "$d/calls"; }
echo 1 >"$d/ps/AC/online"
[ -z "$(run battery)" ] && ok "on mains: the 10-minute step does nothing" || bad "suspended on mains at the battery step"
[ "$(run any)" = suspend ] && ok "on mains: the 20-minute step suspends" || bad "no suspend at the any step"
echo 0 >"$d/ps/AC/online"
[ "$(run battery)" = suspend ] && ok "on battery: suspends" || bad "no suspend on battery"
rm -rf "$d/ps/BAT0"; echo 0 >"$d/ps/AC/online"
[ "$(run battery)" = "" ] && ok "desktop (no battery) counts as mains" || bad "desktop treated as battery"
mkdir -p "$d/ps/BAT0"; echo Battery >"$d/ps/BAT0/type"
echo none >"$d/cfg/hypr/idle-action"
[ -z "$(run any)" ] && ok "idle-action none: never suspends" || bad "none ignored"
echo hibernate >"$d/cfg/hypr/idle-action"
[ "$(run any)" = suspend ] && ok "hibernate without support falls back to suspend" || bad "no fallback"
[ "$(CAN_HIB=yes run any)" = hibernate ] && ok "hibernate when the system can" || bad "hibernate not used"
echo suspend-then-hibernate >"$d/cfg/hypr/idle-action"
[ "$(CAN_HIB=yes run any)" = suspend-then-hibernate ] && ok "suspend-then-hibernate works" || bad "suspend-then-hibernate not used"
grep -q 'dot-power idle-suspend battery' config/hypr/hypridle.conf && grep -q 'dot-power idle-suspend any' config/hypr/hypridle.conf && ok "hypridle.conf has both suspend steps" || bad "hypridle.conf missing the steps"
echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
