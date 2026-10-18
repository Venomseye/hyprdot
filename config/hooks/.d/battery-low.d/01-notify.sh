#!/usr/bin/env bash
#
# Warn about a low battery. Fired by Quickshell's BatteryMonitor when the charge drops to the
# threshold while discharging. Add more scripts to this directory (e.g. switch to a power-saver
# profile) - they all run in parallel.
#
# This script double-checks with the kernel before saying anything, so a wrong reading
# (UPower says 0% for a moment after every reload) can never produce a false alarm, and it
# stays quiet for 20 minutes after warning.
#
# args: $1 = percentage (integer)

command -v notify-send >/dev/null 2>&1 || { echo "notify-send not found, skipping"; exit 0; }

pct="${1:-?}"
for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/capacity" ] || continue
    cap="$(cat "$b/capacity" 2>/dev/null)"
    status="$(cat "$b/status" 2>/dev/null)"
    case "$status" in Charging|Full) echo "battery is $status - no warning"; exit 0 ;; esac
    if [ -n "$cap" ] && [ "$cap" -gt 20 ]; then echo "kernel says $cap% - ignoring the low-battery event"; exit 0; fi
    [ -n "$cap" ] && pct="$cap"
done

stamp="${XDG_RUNTIME_DIR:-/tmp}/battery-low.stamp"
now="$(date +%s)"
if [ -f "$stamp" ] && [ $(( now - $(cat "$stamp" 2>/dev/null || echo 0) )) -lt 1200 ]; then
    echo "already warned recently"
    exit 0
fi
echo "$now" >"$stamp"

notify-send -u critical -a battery "Battery low" "${pct}% remaining - plug in soon"
