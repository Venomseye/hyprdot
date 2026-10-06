#!/usr/bin/env bash
#
# Master dispatcher. wpaperd calls this with: <display> <wallpaper_path>
# (wired up via the `exec` key in ~/.config/wpaperd/config.toml)
#
# Flow:
#   1. point ~/.cache/current-wallpaper at the new wallpaper   (synchronous)
#   2. in the background, serialised by a lock:
#        a. matugen generates every template
#        b. ~/.config/hooks/run-hooks theme-set runs each script in
#           ~/.config/hooks/theme-set.d/ in parallel
#
# The hook returns immediately so wpaperd never waits on matugen or on a slow
# reload. If several wallpaper changes queue up (holding SUPER+SHIFT+W, l), the
# lock serialises them and only the newest one is actually applied.
#
# Deliberately NOT using `set -e`: a failing step must not look like a wpaperd
# problem.

set -uo pipefail

display="${1:-unknown}"
wallpaper="${2:-}"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
LOG="$cache_dir/matugen-hook.log"
LINK="$cache_dir/current-wallpaper"
LOCK="$cache_dir/matugen-hook.lock"
RUN_HOOKS="$config_dir/hooks/run-hooks"

log() { printf '%s  %s\n' "$(date -Is)" "$*" >>"$LOG"; }

# Make sure matugen's output directories exist.
mkdir -p "$cache_dir" "$config_dir/quickshell/theme" "$config_dir/btop/themes"

if [ -z "$wallpaper" ]; then
    log "no wallpaper argument given, nothing to do"
    exit 0
fi

if [ ! -e "$wallpaper" ]; then
    log "wallpaper does not exist: $wallpaper"
    exit 0
fi

# A stable path that always points at whatever is on screen right now.
ln -sfn "$wallpaper" "$LINK" 2>/dev/null || true

if ! command -v matugen >/dev/null 2>&1; then
    log "matugen not found in PATH - install it (AUR: matugen)"
    exit 0
fi

apply_theme() {
    local rc

    # Serialise concurrent runs. Without flock we just run unserialised.
    if command -v flock >/dev/null 2>&1; then
        exec 9>"$LOCK"
        flock 9
    fi

    # Newest wins: if another invocation moved the symlink while we waited for
    # the lock, it will do the work - skip ours.
    if [ "$(readlink "$LINK" 2>/dev/null || true)" != "$wallpaper" ]; then
        log "superseded by a newer wallpaper, skipping $wallpaper"
        return 0
    fi

    printf '\n=== %s | display=%s\nwallpaper=%s\n' "$(date -Is)" "$display" "$wallpaper"

    # `</dev/null` matters: matugen >= 4.0 has an interactive source-colour
    # picker and there's no terminal here, so without it matugen dies with
    # "IO error: Input/output error (os error 5)". source_color_index in
    # matugen/config.toml is the real fix; this is belt and braces.
    matugen image "$wallpaper" --source-color-index 0 </dev/null 2>&1
    rc=$?
    printf 'matugen exit=%d\n' "$rc"

    if [ "$rc" -ne 0 ]; then
        log "matugen failed (exit $rc) - theme-set hooks skipped so nothing reloads stale colours"
        return 0
    fi

    if [ ! -x "$RUN_HOOKS" ]; then
        log "$RUN_HOOKS missing or not executable - theme-set hooks skipped"
        return 0
    fi

    export THEME_WALLPAPER="$wallpaper" THEME_DISPLAY="$display" THEME_MODE="${THEME_MODE:-dark}"
    "$RUN_HOOKS" theme-set "$wallpaper" "$display"
}

# Background it, detached from wpaperd's stdio.
( apply_theme ) </dev/null >>"$LOG" 2>&1 &

# Keep the log from growing without bound.
if [ "$(wc -c <"$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
    tail -c 131072 "$LOG" >"$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
fi

exit 0
