#!/usr/bin/env bash
#
# Live-reload everything that can be reloaded after matugen has written new
# colours. Called by run-hooks (from wpaperd/matugen-hook.sh) once per
# wallpaper change. The five reloads below run in parallel.
#
#   Quickshell  needs no signal: Colors.qml is written inside Quickshell's own
#               config dir and it reloads itself. This only verifies the file
#               was really regenerated, so a template failure shows in the log.
#   Kitty       SIGUSR1: every instance re-reads kitty.conf and its includes.
#   Ghostty     opt-in SIGUSR2 reload (see reload_ghostty).
#   GTK         toggle the theme name so GTK3 re-reads gtk-3.0/colors.css.
#               GTK4/libadwaita apps only read it at startup - reopen them.
#   Hyprland    hyprctl reload, so window borders pick up colors-matugen.lua.
#
# args: $1 = wallpaper path, $2 = display
# env:  THEME_MODE = dark | light (default dark)

set -uo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"

reload_quickshell() {
    local colors="$config_dir/quickshell/theme/Colors.qml"
    if [ ! -s "$colors" ]; then
        echo "quickshell: $colors missing - is [templates.quickshell] in matugen/config.toml?"
        return 1
    fi
    if grep -q BOOTSTRAP "$colors"; then
        echo "quickshell: Colors.qml is still the bootstrap placeholder - matugen did not overwrite it"
        return 1
    fi
    echo "quickshell: Colors.qml regenerated; Quickshell reloads itself"
}

reload_kitty() {
    if ! pgrep -x kitty >/dev/null 2>&1; then
        echo "kitty: not running"
        return 0
    fi
    pkill -USR1 -x kitty && echo "kitty: sent SIGUSR1"
}

# SIGUSR2's DEFAULT action is to terminate the process, so sending it to a
# Ghostty build that doesn't handle it would close every window you have open.
# Recent Ghostty releases should reload on SIGUSR2, but that isn't verified
# against your version, so it's off until you opt in:
#     touch ~/.config/ghostty/.sigusr2-reload
# Without it, new windows get the colours automatically and existing ones via
# the "Reload configuration" action (ctrl+shift+,).
reload_ghostty() {
    if ! pgrep -x ghostty >/dev/null 2>&1; then
        echo "ghostty: not running"
        return 0
    fi
    if [ -e "$config_dir/ghostty/.sigusr2-reload" ]; then
        pkill -USR2 -x ghostty && echo "ghostty: sent SIGUSR2"
    else
        echo "ghostty: running, but SIGUSR2 reload is not enabled (see comment in 01-reload.sh)"
    fi
}

reload_gtk() {
    command -v gsettings >/dev/null 2>&1 || { echo "gtk: gsettings not found, skipping"; return 0; }

    local mode="${THEME_MODE:-dark}" schema="org.gnome.desktop.interface" theme scheme
    # adw-gtk-theme ships "adw-gtk3" (light) and "adw-gtk3-dark"; there is no
    # "adw-gtk3-light".
    if [ "$mode" = "light" ]; then
        theme="adw-gtk3";      scheme="prefer-light"
    else
        theme="adw-gtk3-dark"; scheme="prefer-dark"
    fi

    gsettings set "$schema" color-scheme "$scheme"
    gsettings set "$schema" gtk-theme ""
    sleep 0.15   # keep dconf from coalescing the two writes
    gsettings set "$schema" gtk-theme "$theme" && echo "gtk: theme toggled ($theme)"

    # settings.ini is what GTK3 apps fall back to (and what some read first)
    local v f dark=1
    [ "$mode" = light ] && dark=0
    for v in 3 4; do
        f="$config_dir/gtk-$v.0/settings.ini"
        [ -f "$f" ] || continue
        sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$dark/; s/^gtk-theme-name=.*/gtk-theme-name=$theme/" "$f"
    done
}

reload_hyprland() {
    command -v hyprctl >/dev/null 2>&1 || { echo "hyprland: hyprctl not found, skipping"; return 0; }
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || { echo "hyprland: not inside a Hyprland session, skipping"; return 0; }
    hyprctl reload >/dev/null && echo "hyprland: reloaded"
}

status=0
pids=()
for fn in reload_quickshell reload_kitty reload_ghostty reload_gtk reload_hyprland; do
    "$fn" &
    pids+=("$!")
done
for pid in "${pids[@]}"; do
    wait "$pid" || status=1
done
exit "$status"
