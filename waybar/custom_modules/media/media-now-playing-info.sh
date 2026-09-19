#!/usr/bin/env bash
#
# Prints "Title - Artist" for the active player, or nothing.
# zscroll calls this repeatedly to decide what to scroll.
#
# Keeps a small cache so that a player which briefly fails to answer (Spotify
# does this while switching tracks) shows the last known title instead of
# blinking the whole module out of existence.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEP=$'\x1f'
CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-media-title.cache"

IFS="$SEP" read -r player _status < <("$DIR/get-active-player.sh") || player=""

if [ -z "${player:-}" ]; then
    rm -f "$CACHE_FILE"
    exit 0
fi

fetch() {
    playerctl -p "$player" metadata --format '{{ title }} - {{ artist }}' 2>/dev/null
}

info=$(fetch)

if [ -z "$info" ] || [ "$info" = " - " ]; then
    sleep 0.1
    info=$(fetch)
fi

if [ -n "$info" ] && [ "$info" != " - " ]; then
    printf '%s%s%s\n' "$player" "$SEP" "$info" > "$CACHE_FILE"
    printf '%s\n' "$info"
    exit 0
fi

# Fall back to the cached title, but only if it belongs to this same player.
if [ -r "$CACHE_FILE" ]; then
    IFS="$SEP" read -r cached_player cached_value < "$CACHE_FILE" || true
    if [ "${cached_player:-}" = "$player" ] && [ -n "${cached_value:-}" ]; then
        printf '%s\n' "$cached_value"
    fi
fi
