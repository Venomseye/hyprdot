#!/usr/bin/env bash
#
# Browse wallpapers with real thumbnails in rofi and jump straight to one,
# instead of blindly cycling through the folder with next/previous.
#
# THE REAL LIMITATION THIS WORKS AROUND: wpaperd/wpaperctl has no released,
# stable command to jump to one specific wallpaper by path. The only such
# feature I could find (`wpaperctl set <monitor> <path>`) is an open,
# UNMERGED pull request as of my research - not something to depend on.
#
# What wpaperd DOES confirm supporting is hot config reloading for every
# setting (its own README: "Hot config reloading for all settings"). So this
# script "flashes" wpaperd's `path` setting to point at just the one chosen
# file, waits for wpaperd to notice and switch to it (which fires the normal
# matugen hook, exactly like any other wallpaper change), then immediately
# reverts `path` back to the wallpaper folder - so SUPER+SHIFT+W's next/
# previous cycling keeps working normally afterward. It's a workaround for a
# missing feature, not a first-class API, and it depends on wpaperd noticing
# the config change within WAIT_SECONDS - if a wallpaper picked this way
# doesn't seem to switch, try increasing that value first.

set -uo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WPAPERD_CONFIG="$HOME/.config/wpaperd/config.toml"
WAIT_SECONDS=0.6

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper picker" "Folder not found: $WALLPAPER_DIR" 2>/dev/null
    exit 1
fi

# Build the rofi entry list: filename shown, thumbnail:// tells rofi to use
# its own built-in XDG-thumbnailer system for a real image preview (confirmed
# against rofi's own rofi-thumbnails(5) man page - needs -show-icons passed
# to rofi, and a thumbnailer for image mimetypes, which is standard on any
# desktop that already thumbnails images in a file manager).
entries=""
while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    entries+="${name}\0icon\x1fthumbnail://${file}\n"
done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 | sort -z)

if [ -z "$entries" ]; then
    notify-send "Wallpaper picker" "No images found in $WALLPAPER_DIR" 2>/dev/null
    exit 1
fi

chosen_name=$(printf "$entries" | rofi -dmenu -show-icons -p "Wallpaper")
[ -z "$chosen_name" ] && exit 0

chosen_path="$WALLPAPER_DIR/$chosen_name"
if [ ! -f "$chosen_path" ]; then
    notify-send "Wallpaper picker" "Couldn't find: $chosen_name" 2>/dev/null
    exit 1
fi

if [ ! -f "$WPAPERD_CONFIG" ]; then
    notify-send "Wallpaper picker" "wpaperd config not found" 2>/dev/null
    exit 1
fi

# Flash path -> the chosen file, then revert -> the folder. Only touches the
# `path = ` line under [default]; every other wpaperd setting is untouched.
sed -i "s|^path = .*|path = \"${chosen_path}\"|" "$WPAPERD_CONFIG"
sleep "$WAIT_SECONDS"
sed -i "s|^path = .*|path = \"${WALLPAPER_DIR}\"|" "$WPAPERD_CONFIG"
