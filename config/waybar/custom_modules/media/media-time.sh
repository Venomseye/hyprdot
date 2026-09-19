#!/usr/bin/env bash
#
# Prints "1:23/4:56" for the active player.
#
# THIS SCRIPT WAS NEVER WIRED UP. It existed, it worked, style.css even had a
# #custom-media-time rule for it, but "custom/media-time" never appeared in
# waybar's config.jsonc so it was dead code. It's in the media group now.
#
# Two calls to playerctl instead of four: title/artist/length come back from a
# single --format call. `position` stays separate on purpose - the bare
# `playerctl position` command returns SECONDS, while the {{ position }}
# format variable returns microseconds, and mixing those up is exactly the bug
# the "do not divide" comment below is guarding against.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEP=$'\x1f'
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-media-time.state"

IFS="$SEP" read -r player status < <("$DIR/get-active-player.sh") || { player=""; status=""; }

if [ -z "${player:-}" ]; then
    rm -f "$STATE_FILE"
    exit 0
fi

now=$(date +%s.%N)

meta=$(playerctl -p "$player" metadata \
    --format "{{ title }}${SEP}{{ artist }}${SEP}{{ mpris:length }}" 2>/dev/null)
IFS="$SEP" read -r title artist length_us <<< "$meta"

raw_pos=$(playerctl -p "$player" position 2>/dev/null)   # SECONDS - do not divide

length=""
if [ -n "${length_us:-}" ] && [ "$length_us" -eq "$length_us" ] 2>/dev/null; then
    length=$(awk "BEGIN{printf \"%.4f\", $length_us/1000000}")
fi

prev_player=""; prev_title=""; prev_artist=""; prev_pos=""
prev_ts=""; prev_length=""; prev_status=""
if [ -r "$STATE_FILE" ]; then
    IFS="$SEP" read -r prev_player prev_title prev_artist prev_pos prev_ts prev_length prev_status \
        < "$STATE_FILE" || true
fi

if [ -n "${raw_pos:-}" ]; then
    # Trust the real position whenever the player gives us one. This is what
    # keeps the display in sync with actual playback, seeks, and switching
    # between different sources.
    base_pos="$raw_pos"
else
    # Player didn't answer this particular tick - bridge the gap by
    # extrapolating from the last known position instead of showing nothing.
    # Self-corrects the moment a real reading comes back.
    same_track=false
    if [ "$player" = "${prev_player:-}" ] &&
       [ "${title:-}" = "${prev_title:-}" ] &&
       [ "${artist:-}" = "${prev_artist:-}" ]; then
        same_track=true
    fi

    if $same_track && [ -n "${prev_pos:-}" ] && [ -n "${prev_ts:-}" ]; then
        if [ "$status" = "Playing" ]; then
            elapsed=$(awk "BEGIN{print $now - $prev_ts}")
            base_pos=$(awk "BEGIN{printf \"%.4f\", $prev_pos + $elapsed}")
        else
            base_pos="$prev_pos"
        fi
    else
        base_pos="0"
    fi
fi

[ -z "$length" ] && length="${prev_length:-}"

# Never let the extrapolated position overshoot the track length.
if [ -n "$length" ] && awk "BEGIN{exit !($base_pos > $length)}" 2>/dev/null; then
    base_pos="$length"
fi

tmp="$STATE_FILE.$$"
printf '%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
    "$player" "$SEP" "${title:-}" "$SEP" "${artist:-}" "$SEP" "$base_pos" "$SEP" \
    "$now" "$SEP" "$length" "$SEP" "$status" > "$tmp" 2>/dev/null &&
    mv -f "$tmp" "$STATE_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null

fmt_time() {
    local secs=${1:-}
    if [ -z "$secs" ]; then
        echo "0:00"
        return
    fi
    # Round to nearest second rather than truncating. Truncation is what made
    # every track display roughly one second short of its real length.
    secs=$(printf '%.0f' "$secs" 2>/dev/null) || { echo "0:00"; return; }
    local h=$((secs/3600))
    local m=$(((secs%3600)/60))
    local s=$((secs%60))
    if [ "$h" -gt 0 ]; then
        printf "%d:%02d:%02d" "$h" "$m" "$s"
    else
        printf "%d:%02d" "$m" "$s"
    fi
}

printf '%s/%s\n' "$(fmt_time "$base_pos")" "$(fmt_time "$length")"
