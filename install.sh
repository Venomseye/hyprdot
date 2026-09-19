#!/usr/bin/env bash
#
# Copies these configs into ~/.config, backing up anything it replaces.
#
#   ./install.sh            install
#   ./install.sh --dry-run  print what would happen, change nothing
#
# Nothing is deleted. Files you have that aren't in this bundle are left alone.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$DEST-backup-$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "-n" ] && DRY_RUN=true

say()  { printf '%s\n' "$*"; }
run()  { if $DRY_RUN; then printf '  would: %s\n' "$*"; else "$@"; fi; }

if [ ! -d "$SRC" ]; then
    say "error: can't find $SRC"
    exit 1
fi

$DRY_RUN && say "=== DRY RUN - nothing will be changed ==="
say "source:  $SRC"
say "dest:    $DEST"
say "backup:  $BACKUP"
say ""

backed_up=0
installed=0

while IFS= read -r -d '' file; do
    rel="${file#"$SRC"/}"
    target="$DEST/$rel"

    if [ -e "$target" ]; then
        if cmp -s "$file" "$target"; then
            say "unchanged  $rel"
            continue
        fi
        run mkdir -p "$(dirname "$BACKUP/$rel")"
        run cp -a "$target" "$BACKUP/$rel"
        backed_up=$((backed_up + 1))
        say "replace    $rel   (old copy -> backup)"
    else
        say "new        $rel"
    fi

    run mkdir -p "$(dirname "$target")"
    run cp "$file" "$target"
    installed=$((installed + 1))
done < <(find "$SRC" -type f -print0 | sort -z)

# Everything that needs to be executable.
for s in \
    "waybar/auto-reload.sh" \
    "waybar/custom_modules/media/get-active-player.sh" \
    "waybar/custom_modules/media/media-animation.sh" \
    "waybar/custom_modules/media/media-now-playing.sh" \
    "waybar/custom_modules/media/media-now-playing-info.sh" \
    "waybar/custom_modules/media/media-now-playing-wrap.sh" \
    "waybar/custom_modules/media/media-time.sh" \
    "wpaperd/matugen-hook.sh"
do
    run chmod +x "$DEST/$s"
done

say ""
say "installed: $installed file(s), backed up: $backed_up"

# Files from the old setup that should go away. Not deleted automatically -
# just reported, so you can look before you leap.
say ""
say "--- consider removing (see README section 5) ---"
for stale in "hypr/hyprland.conf" "ghostty/config.ghostty"; do
    [ -e "$DEST/$stale" ] && say "  $DEST/$stale"
done

if ! $DRY_RUN; then
    say ""
    say "Next: RESTART Hyprland (not hyprctl reload) so the new hyprlock"
    say "screencopy permission takes effect. Then run the checks in README"
    say "section 7."
fi
