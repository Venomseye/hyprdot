#!/usr/bin/env bash
#
# Prints "player<US>status" for whichever player is currently Playing, falling
# back to the first player with any known status (e.g. Paused).
# Prints nothing at all when no player exists.
#
# <US> is the ASCII unit separator (0x1f), NOT a tab. Tab is IFS whitespace in
# bash, so `IFS=$'\t' read -r a b` silently collapses an empty leading field and
# shifts everything left. 0x1f is not whitespace, so empty fields survive.
#
# TWO FIXES OVER THE OLD VERSION:
#
# 1. playerctld is filtered out. You run `playerctld daemon` at startup and it
#    registers itself as an MPRIS player, so it shows up in `playerctl -l`
#    alongside real players. It is only ever a proxy for whatever is actually
#    playing, so letting it win the "first Playing player" race gave you
#    duplicate and occasionally stale metadata.
#
# 2. Results are cached for CACHE_MS. Three waybar modules call this on tight
#    loops - the animation one every 0.1s. Uncached that was 20-40 playerctl
#    processes a second, forever, for a three-character bar graph.

set -uo pipefail

SEP=$'\x1f'
CACHE_MS=700
CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-active-player.cache"

now_ms() {
    local ns
    ns=$(date +%s%N)
    echo $(( ns / 1000000 ))
}

emit() {
    # $1 = player, $2 = status. Prints nothing when there's no player.
    # Must use $SEP, not a tab: every caller parses this with IFS="$SEP".
    [ -n "${1:-}" ] && printf '%s%s%s\n' "$1" "$SEP" "$2"
    return 0
}

now=$(now_ms)

# --- serve from cache if it's fresh enough --------------------------------
if [ -r "$CACHE_FILE" ]; then
    IFS="$SEP" read -r stamp c_player c_status < "$CACHE_FILE" || true
    if [ -n "${stamp:-}" ] && [ "$stamp" -eq "$stamp" ] 2>/dev/null; then
        if [ $((now - stamp)) -lt "$CACHE_MS" ]; then
            emit "${c_player:-}" "${c_status:-}"
            exit 0
        fi
    fi
fi

# --- otherwise do a real lookup -------------------------------------------
players=$(playerctl --list-all 2>/dev/null | grep -vx 'playerctld' || true)

player=""
status=""
fallback_player=""
fallback_status=""

if [ -n "$players" ]; then
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        s=$(playerctl -p "$p" status 2>/dev/null)
        if [ "$s" = "Playing" ]; then
            player="$p"
            status="$s"
            break
        fi
        if [ -z "$fallback_player" ] && [ -n "$s" ]; then
            fallback_player="$p"
            fallback_status="$s"
        fi
    done <<< "$players"
fi

if [ -z "$player" ] && [ -n "$fallback_player" ]; then
    player="$fallback_player"
    status="$fallback_status"
fi

# Write atomically - several modules read this concurrently and a half-written
# cache line would desync every one of them.
tmp="$CACHE_FILE.$$"
printf '%s%s%s%s%s\n' "$now" "$SEP" "$player" "$SEP" "$status" > "$tmp" 2>/dev/null &&
    mv -f "$tmp" "$CACHE_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null

emit "$player" "$status"
