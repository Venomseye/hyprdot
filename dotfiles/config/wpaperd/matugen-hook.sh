#!/usr/bin/env bash
#
# wpaperd calls this with: <display> <wallpaper_path>
# Wired up via the `exec` key in ~/.config/wpaperd/config.toml
#
# Deliberately NOT using `set -e`: if matugen fails we still want the symlink
# and the log entry, and we never want a non-zero exit to look like a wpaperd
# problem.

set -uo pipefail

display="${1:-unknown}"
wallpaper="${2:-}"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
LOG="$cache_dir/matugen-hook.log"
LINK="$cache_dir/current-wallpaper"

mkdir -p "$cache_dir"

if [ -z "$wallpaper" ]; then
    printf '%s  no wallpaper argument given, nothing to do\n' "$(date -Is)" >>"$LOG"
    exit 0
fi

# A stable path that always points at whatever is on screen right now.
# hyprlock, preview scripts, etc. can use this instead of guessing filenames.
ln -sfn "$wallpaper" "$LINK" 2>/dev/null || true

# `</dev/null` is the important bit. matugen >= 4.0 has an interactive source
# colour picker and this script has no controlling terminal, so without it
# matugen dies with "IO error: Input/output error (os error 5)".
#
# The real fix is `source_color_index` in ~/.config/matugen/config.toml - this
# is belt and braces in case that config ever gets replaced or goes missing.
{
    printf '\n=== %s | display=%s\n' "$(date -Is)" "$display"
    printf 'wallpaper=%s\n' "$wallpaper"
    matugen image "$wallpaper" --source-color-index 0 </dev/null 2>&1
    printf 'matugen exit=%d\n' "$?"
} >>"$LOG" 2>&1

# Keep the log from growing without bound.
if [ "$(wc -c <"$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
    tail -c 131072 "$LOG" >"$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
fi
