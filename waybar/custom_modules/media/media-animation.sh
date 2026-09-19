#!/usr/bin/env bash
#
# Little equaliser animation for the media group. Emits a frame while something
# is playing, an empty line otherwise (waybar hides a module whose text is
# empty).
#
# Available block glyphs: ▁ ▂ ▃ ▄ ▅ ▆ ▇ █
#
# The expensive part used to be that every single frame shelled out to
# get-active-player.sh, which itself ran `playerctl -l` plus one `playerctl
# status` per player. At 10 frames a second that is a permanent 20-40
# processes/sec background load. get-active-player.sh now caches for ~0.7s, and
# this script only re-checks every STATUS_EVERY frames on top of that.
#
# It also only prints when the output actually changes, which stops waybar
# redrawing the bar ten times a second for no reason.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEP=$'\x1f'

FRAME_DELAY=0.12
STATUS_EVERY=5   # re-read player status every N frames

frames=("▂▄▆" "▄▂▆" "▄▆▂" "▆▄▂" "▆▂▄")

status=""
last_output="__init__"
tick=0

while :; do
    for frame in "${frames[@]}"; do
        if (( tick % STATUS_EVERY == 0 )); then
            IFS="$SEP" read -r _ status < <("$DIR/get-active-player.sh") || status=""
        fi
        tick=$(( tick + 1 ))

        if [ "${status:-}" = "Playing" ]; then
            output="$frame"
        else
            output=""
        fi

        if [ "$output" != "$last_output" ]; then
            printf '%s\n' "$output"
            last_output="$output"
        fi

        sleep "$FRAME_DELAY"
    done
done
