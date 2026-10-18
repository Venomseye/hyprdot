#!/usr/bin/env bash
#
# Delayed startup tasks, run once per login by Hyprland's autostart
# (`run-hooks post-boot`). Put slow or order-sensitive things here instead of
# in autostart.lua.
#
#   1. Make sure wpaperd is running (autostart normally started it).
#   2. Make sure an initial wallpaper has been applied. wpaperd applies its
#      own on startup, and its exec hook records it in
#      ~/.cache/current-wallpaper. If that never appeared, nudge wpaperd.
#   3. If Quickshell's Colors.qml is still the bootstrap placeholder (fresh
#      install, wiped cache), regenerate every colour file from that wallpaper
#      now instead of waiting for the next wallpaper change.

cache="${XDG_CACHE_HOME:-$HOME/.cache}"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
link="$cache/current-wallpaper"
colors="$config/quickshell/theme/Colors.qml"
hook="$config/wpaperd/matugen-hook.sh"

wait_for() {  # wait_for <seconds> <test command...>
    local tries=$(( $1 * 2 )) i
    shift
    for ((i = 0; i < tries; i++)); do
        "$@" && return 0
        sleep 0.5
    done
    return 1
}

# 1. wpaperd
if command -v wpaperd >/dev/null 2>&1 && ! pgrep -x wpaperd >/dev/null 2>&1; then
    echo "wpaperd not running - starting it"
    if command -v setsid >/dev/null 2>&1; then
        setsid -f wpaperd -d >/dev/null 2>&1 </dev/null
    else
        nohup wpaperd -d >/dev/null 2>&1 </dev/null &
    fi
fi

# 2. initial wallpaper
if ! wait_for 10 test -e "$link"; then
    if command -v wpaperctl >/dev/null 2>&1 && pgrep -x wpaperd >/dev/null 2>&1; then
        echo "no wallpaper recorded after 10s - asking wpaperd for one"
        wpaperctl next-wallpaper
        wait_for 5 test -e "$link"
    fi
fi
if [ ! -e "$link" ]; then
    echo "still no $link - wpaperd has no wallpaper configured yet; nothing to theme from"
    exit 0
fi

# 3. bootstrap colours -> real colours
if [ -s "$colors" ] && ! grep -q BOOTSTRAP "$colors"; then
    echo "colours already generated - nothing to do"
    exit 0
fi
[ -x "$hook" ] || { echo "$hook missing or not executable"; exit 1; }

echo "Colors.qml is still the placeholder - regenerating from $(readlink -f "$link")"
"$hook" post-boot "$(readlink -f "$link")"
