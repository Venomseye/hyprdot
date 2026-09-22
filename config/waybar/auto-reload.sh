#!/usr/bin/env bash
#
# Reload waybar when its config or scripts change.
#
# FIXES OVER THE OLD ONE-LINER:
#   -m   keep running. The old `while inotifywait ...; do` form exited and
#        restarted the watch after every event, which drops events that land
#        in the gap.
#   -r   recurse. The old version watched only the top level of
#        ~/.config/waybar, so every edit under custom_modules/ was ignored.
#   moved_to  editors like vim and neovim save by writing a temp file and
#        renaming it over the target. That never fires close_write on the
#        target, so those saves were invisible.
#   excluding waybar-colors.css  [FIX] this file already has its own gentle
#        reload path (reload_style_on_change in config.jsonc), which only
#        refreshes CSS. Watching it here too meant every wallpaper change
#        triggered a SECOND, harder SIGUSR2 reset from this script, on top of
#        the one matugen's own post_hook used to send. SIGUSR2's default
#        action is a full bar reset - not a style refresh - and that reset
#        was what made the wallpaper submap's icon vanish the instant a new
#        wallpaper applied: hyprland/submap's displayed text comes from live
#        Hyprland IPC events, and a full reset rebuilds that module with no
#        memory of "we're still in a submap right now." Removed matugen's
#        post_hook for the same reason; this exclusion covers the case where
#        something else ever rewrites that file too.
#
# So: this script is now purely about config.jsonc and the custom module
# scripts. CSS is handled entirely by waybar's own reload_style_on_change.

set -uo pipefail

WATCH="$HOME/.config/waybar"

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "waybar/auto-reload.sh: inotify-tools is not installed" >&2
    exit 1
fi

inotifywait -q -m -r -e close_write -e moved_to --format '%w%f' "$WATCH" |
while read -r changed; do
    case "$changed" in
        *.swp|*.swx|*.swo|*~|*.tmp|*4913) continue ;;
        */waybar-colors.css) continue ;;
    esac

    # Debounce - a single editor save can emit several close_write events in
    # quick succession; without this waybar gets reloaded several times in a
    # row for one actual change.
    sleep 0.4
    pkill -USR2 -x waybar || true
done
