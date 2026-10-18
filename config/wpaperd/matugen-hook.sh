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
# reload. If several wallpaper changes queue up (holding SUPER+CTRL+W), the
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
mkdir -p "$cache_dir" "$config_dir/quickshell/theme" "$config_dir/btop/themes" "$config_dir/qt5ct/colors" "$config_dir/qt6ct/colors"

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
    # Optional colour-scheme settings from `dot-wallpaper theme` (mode light|dark and a
    # scheme style). If matugen rejects them for any reason, retry plain so a bad
    # setting can never leave the desktop without colours.
    local conf="${XDG_STATE_HOME:-$HOME/.local/state}/dot-wallpaper/theme.conf" mode="" style="" opts=()
    if [ -r "$conf" ]; then
        mode="$(sed -n 's/^MODE=//p' "$conf" | head -n 1)"
        style="$(sed -n 's/^STYLE=//p' "$conf" | head -n 1)"
    fi
    [ "$mode" = light ] && opts+=(-m light)
    [ -n "$style" ] && [ "$style" != tonal-spot ] && opts+=(-t "scheme-$style")
    export THEME_MODE="${mode:-${THEME_MODE:-dark}}"

    # wpaperd runs this hook once PER DISPLAY, all with the same wallpaper. Without this
    # check matugen and every reload hook ran twice per change. Mode/style are part of the
    # key, so changing the scheme on the same wallpaper is never skipped.
    local key="$wallpaper|${mode:-dark}|${style:-tonal-spot}" stamp="$cache_dir/matugen-last-applied" age
    if [ -r "$stamp" ] && [ "$(head -n 1 "$stamp" 2>/dev/null)" = "$key" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$stamp" 2>/dev/null || echo 0) ))
        if [ "$age" -ge 0 ] && [ "$age" -lt 8 ]; then
            log "already applied ${age}s ago (another display), skipping $wallpaper"
            return 0
        fi
    fi

    matugen image "$wallpaper" --source-color-index 0 "${opts[@]}" </dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ] && [ "${#opts[@]}" -gt 0 ]; then
        # first keep just the light/dark choice, then nothing at all
        if [ "$mode" = light ] && [ "${#opts[@]}" -gt 2 ]; then
            printf 'matugen rejected %s (exit %d) - retrying with only -m light\n' "${opts[*]}" "$rc"
            matugen image "$wallpaper" --source-color-index 0 -m light </dev/null 2>&1
            rc=$?
        fi
        if [ "$rc" -ne 0 ]; then
            printf 'matugen rejected its options (exit %d) - retrying plain\n' "$rc"
            matugen image "$wallpaper" --source-color-index 0 </dev/null 2>&1
            rc=$?
        fi
    fi
    printf 'matugen exit=%d\n' "$rc"
    [ "$rc" -eq 0 ] && printf '%s\n' "$key" >"$stamp" 2>/dev/null

    if [ "$rc" -ne 0 ]; then
        log "matugen failed (exit $rc) - theme-set hooks skipped so nothing reloads stale colours"
        return 0
    fi

    if [ ! -x "$RUN_HOOKS" ]; then
        log "$RUN_HOOKS missing or not executable - theme-set hooks skipped"
        return 0
    fi

    export THEME_WALLPAPER="$wallpaper" THEME_DISPLAY="$display"
    "$RUN_HOOKS" theme-set "$wallpaper" "$display"
}

# Background it, detached from wpaperd's stdio.
( apply_theme ) </dev/null >>"$LOG" 2>&1 &

# Keep the log from growing without bound.
if [ "$(wc -c <"$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
    tail -c 131072 "$LOG" >"$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
fi

exit 0
