#!/usr/bin/env bash
#
# Wraps zscroll's plain scrolling text into waybar's JSON module format, adding
# a play/pause icon and a full-detail hover tooltip.
# Reads scrolled lines from stdin (piped in from zscroll).
#
# CHANGED: the old version made three separate `playerctl metadata` calls per
# scrolled line (title, artist, album) on top of the get-active-player call.
# At zscroll's 0.3s delay that's over 13 processes a second just to render a
# tooltip nobody is looking at most of the time. One --format call now fetches
# all three fields at once.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEP=$'\x1f'

have_jq=false
command -v jq >/dev/null 2>&1 && have_jq=true

emit() {
    local text="$1" tooltip="$2"
    if $have_jq; then
        jq -cn --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
    else
        # jq not installed - basic manual JSON escaping
        local esc_text esc_tooltip
        esc_text=$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')
        esc_tooltip=$(printf '%s' "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        printf '{"text": "%s", "tooltip": "%s"}\n' "$esc_text" "$esc_tooltip"
    fi
}

while IFS= read -r line; do
    IFS="$SEP" read -r player status < <("$DIR/get-active-player.sh") || { player=""; status=""; }

    if [ -n "${player:-}" ]; then
        meta=$(playerctl -p "$player" metadata \
            --format "{{ title }}${SEP}{{ artist }}${SEP}{{ album }}" 2>/dev/null)
        IFS="$SEP" read -r full_title full_artist album <<< "$meta"

        # Show the action the click will perform: a pause glyph while playing,
        # a play glyph while paused.
        if [ "$status" = "Playing" ]; then
            icon="⏸"
        else
            icon="▶"
        fi

        tooltip="${full_title:-}"
        [ -n "${full_artist:-}" ] && tooltip="$tooltip
by $full_artist"
        [ -n "${album:-}" ] && tooltip="$tooltip
$album"

        emit "$icon $line" "$tooltip"
    else
        emit "$line" ""
    fi
done
