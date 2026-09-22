#!/usr/bin/env bash
#
# Reports the default microphone's mute state as a waybar custom-module JSON
# payload, with a REAL CSS class (not embedded Pango markup) so its colour
# tracks matugen's live @urgent value automatically, the same way
# #pulseaudio.muted already does for the speaker.
#
# WHY THIS EXISTS (replacing the old {format_source}-embedded approach):
# the mic glyph used to live inside the SAME text label as the speaker icon,
# coloured via a hardcoded literal hex value in a Pango <span> tag (Pango
# spans can't reference a GTK CSS custom property like @urgent). Every time
# matugen regenerated @urgent for a new wallpaper, the speaker's colour
# updated live but the mic's hardcoded value didn't - so after a reboot (or
# any wallpaper change), the two reds could visibly mismatch, one dynamic,
# one stuck at whatever value was hardcoded when this was written. A
# separate module gets a real, independent CSS node, so a real CSS rule
# using the real @urgent variable can apply to it - no hardcoded colour,
# no drift, ever.
#
# `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` output format confirmed against
# multiple independent real-world implementations (a waybar volume script
# gist, a Rust status-bar crate, WirePlumber's own feature-request MR):
#   "Volume: 0.45"          when unmuted
#   "Volume: 0.45 [MUTED]"  when muted

set -uo pipefail

mic_icon=$'\uf130'         # fa-microphone       (verified: fontawesome.com/v4/icon/microphone)
mic_muted_icon=$'\uf131'   # fa-microphone-slash (verified: fontawesome.com/v4/icon/microphone-slash)

out=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)

if [ -z "$out" ]; then
    # No default source at all (e.g. no mic connected) - show nothing rather
    # than a misleading icon. Custom modules with empty text auto-hide.
    printf '{"text": "", "tooltip": "No microphone"}\n'
    exit 0
fi

if [[ "$out" == *"[MUTED]"* ]]; then
    printf '{"text": "%s", "class": "muted", "tooltip": "Microphone muted"}\n' "$mic_muted_icon"
else
    printf '{"text": "%s", "tooltip": "Microphone unmuted"}\n' "$mic_icon"
fi
