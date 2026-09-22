#!/usr/bin/env bash
#
# Copies these configs into ~/.config, backing up anything it replaces, and
# optionally installs the packages they depend on.
#
#   ./install.sh                    install configs
#   ./install.sh --dry-run          print what would happen, change nothing
#   ./install.sh --with-deps        also install dependencies (pacman/AUR)
#   ./install.sh --with-deps --dry-run   preview both, changes nothing
#   ./install.sh --help             this message
#
# Nothing is deleted. Files you have that aren't in this bundle are left alone.
#
# --with-deps is Arch-specific (pacman + an AUR helper). Every package name
# below was checked individually against Arch's own package search before
# being put in either list - not guessed. In particular:
#   - matugen has NO official package; it's AUR-only.
#   - "rofi" alone does not have working Wayland/layer-shell support on this
#     stack - the correct package is rofi-wayland, which provides/conflicts
#     with plain rofi. Installing "rofi" here would silently give you a
#     launcher that doesn't display right under Hyprland.
#   - wpaperd, satty, cliphist, and adw-gtk-theme are all official `extra`
#     packages now, despite older guides sometimes listing them as AUR.
# If you're not on an Arch-based distro, --with-deps prints both lists and
# stops there - translate the names for your distro's package manager
# yourself, since I can't verify those in the same way from here.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$DEST-backup-$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
WITH_DEPS=false

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=true ;;
        --with-deps|-d) WITH_DEPS=true ;;
        --help|-h)
            sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "unknown option: $arg (see --help)" >&2
            exit 1
            ;;
    esac
done

say()  { printf '%s\n' "$*"; }
run()  { if $DRY_RUN; then printf '  would: %s\n' "$*"; else "$@"; fi; }

if [ ! -d "$SRC" ]; then
    say "error: can't find $SRC"
    exit 1
fi

$DRY_RUN && say "=== DRY RUN - nothing will be changed ==="

# ---------------------------------------------------------------------------
# Dependencies (only runs with --with-deps)
# ---------------------------------------------------------------------------

# Confirmed in Arch's official `extra` repo - verified individually, not
# assumed from an older guide.
OFFICIAL_PKGS=(
    hyprland hyprlock hypridle
    waybar wpaperd
    rofi-wayland
    kitty mako
    playerctl jq inotify-tools
    grim slurp satty wl-clipboard cliphist
    brightnessctl wireplumber
    adw-gtk-theme
)

# Confirmed AUR-only - no official package exists for these.
AUR_PKGS=(
    matugen
    zscroll
)

install_dependencies() {
    say "=== Dependencies ==="

    if ! command -v pacman >/dev/null 2>&1; then
        say "pacman not found - this dependency list is Arch-specific."
        say "Official-repo packages (translate for your distro):"
        printf '  %s\n' "${OFFICIAL_PKGS[@]}"
        say "AUR-only packages (find an equivalent or build from source):"
        printf '  %s\n' "${AUR_PKGS[@]}"
        say ""
        return
    fi

    say "Official repo (pacman): ${OFFICIAL_PKGS[*]}"
    if $DRY_RUN; then
        say "  would: sudo pacman -S --needed ${OFFICIAL_PKGS[*]}"
    else
        sudo pacman -S --needed "${OFFICIAL_PKGS[@]}"
    fi
    say ""

    local aur_helper=""
    for helper in yay paru; do
        if command -v "$helper" >/dev/null 2>&1; then
            aur_helper="$helper"
            break
        fi
    done

    say "AUR-only (matugen has no official package, zscroll is a small"
    say "  scrolling-text helper): ${AUR_PKGS[*]}"
    if [ -n "$aur_helper" ]; then
        if $DRY_RUN; then
            say "  would: $aur_helper -S --needed ${AUR_PKGS[*]}"
        else
            "$aur_helper" -S --needed "${AUR_PKGS[@]}"
        fi
    else
        say "  No AUR helper (yay/paru) found - install one first, then run:"
        say "    yay -S --needed ${AUR_PKGS[*]}"
        say "  zscroll only affects the scrolling media title - the script"
        say "  degrades to unscrolled text without it, so it's safe to skip"
        say "  for now if you don't want to set up an AUR helper yet."
    fi
    say ""
}

if $WITH_DEPS; then
    install_dependencies
fi

# ---------------------------------------------------------------------------
# Config files
# ---------------------------------------------------------------------------

say "=== Config files ==="
say "source:  $SRC"
say "dest:    $DEST"
say "backup:  $BACKUP"
say ""

# [FIX] These 8 files are matugen's own OUTPUT - regenerated every time you
# change wallpaper. The copies shipped in config/ are bootstrap placeholders,
# there only so nothing references a missing file before matugen has run for
# the first time. Every previous version of this installer treated them like
# any other config file: "different from the shipped copy -> back up and
# overwrite." But matugen changing them IS the whole point of this system -
# a live, correctly wallpaper-matched file is SUPPOSED to differ from the
# static placeholder, and a naive re-run of install.sh was silently
# stomping real, working colours back to these hardcoded defaults. (Found
# this from a real report: waybar's mute-icon red went from a genuine
# matugen-generated `#ffb4ab` right after boot to the shipped placeholder's
# exact `#e35149` a few minutes later - install.sh had been run again in
# between and clobbered the live file.)
#
# Fix: once a file in this list already exists at the destination, leave it
# completely alone - don't compare it, don't back it up, don't touch it.
# Only install the bootstrap default if the destination doesn't exist yet
# at all (a genuinely first-time install).
GENERATED_FILES=(
    "waybar/waybar-colors.css"
    "kitty/colors-matugen.conf"
    "ghostty/colors-matugen"
    "mako/mako-colors"
    "rofi/colors-matugen.rasi"
    "hypr/colors-matugen.lua"
    "gtk-3.0/colors.css"
    "gtk-4.0/colors.css"
)

is_generated_file() {
    local rel="$1"
    local g
    for g in "${GENERATED_FILES[@]}"; do
        [ "$rel" = "$g" ] && return 0
    done
    return 1
}

backed_up=0
installed=0
left_alone=0

while IFS= read -r -d '' file; do
    rel="${file#"$SRC"/}"
    target="$DEST/$rel"

    if is_generated_file "$rel" && [ -e "$target" ]; then
        say "live       $rel   (matugen-generated - left alone, not overwritten)"
        left_alone=$((left_alone + 1))
        continue
    fi

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
    "waybar/custom_modules/mic-status.sh" \
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
say "installed: $installed file(s), backed up: $backed_up, left alone (live matugen output): $left_alone"

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
