#!/usr/bin/env bash
#
# Scrolling "now playing" text for waybar.
#
# zscroll produces plain scrolled lines; media-now-playing-wrap.sh turns each
# one into the JSON object waybar wants (text + tooltip).

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v zscroll >/dev/null 2>&1; then
    # Degrade gracefully instead of leaving a permanently blank module with no
    # explanation. Fall back to unscrolled text.
    while :; do
        "$DIR/media-now-playing-info.sh"
        sleep 2
    done | "$DIR/media-now-playing-wrap.sh"
    exit 0
fi

zscroll -l 20 \
    --delay 0.3 \
    --update-check true \
    "$DIR/media-now-playing-info.sh" | "$DIR/media-now-playing-wrap.sh"
