#!/usr/bin/env bash
#
# Reload waybar when its config or scripts change.
#
# THREE FIXES OVER THE OLD ONE-LINER:
#   -m   keep running. The old `while inotifywait ...; do` form exited and
#        restarted the watch after every event, which drops events that land
#        in the gap.
#   -r   recurse. The old version watched only the top level of
#        ~/.config/waybar, so every edit under custom_modules/ was ignored.
#   moved_to  editors like vim and neovim save by writing a temp file and
#        renaming it over the target. That never fires close_write on the
#        target, so those saves were invisible.
#
# CSS is handled by waybar itself now (reload_style_on_change in config.jsonc),
# so this is really about config.jsonc and the media scripts.

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
    esac

    # Debounce. matugen rewrites waybar-colors.css and then fires its own
    # SIGUSR2, and a single editor save can emit several events; without this
    # waybar gets reloaded three or four times in a row.
    sleep 0.4
    pkill -USR2 -x waybar || true
done
