# Making apps read the matugen colours

install.sh seeds a `colors-matugen*` file for each app; matugen overwrites it on
every wallpaper change. Each app still has to be told to *read* it. Add these
lines to your existing config files (they're not shipped, so your own settings
aren't overwritten).

## Kitty - `config/kitty/kitty.conf`

```conf
include colors-matugen.conf
```

Put it **after** any `foreground`, `background` or `colorN` lines you set by
hand - the last value wins. Running instances reload on SIGUSR1, which
`hooks/.d/theme-set.d/01-reload.sh` sends.

## Ghostty - `config/ghostty/config`

```conf
config-file = ?colors-matugen
```

The path is relative to the file containing it, and the `?` stops Ghostty
complaining if the file is missing. Same rule: put it after hand-set colours.
New windows pick up changes automatically; for existing ones use the "Reload
configuration" action, or enable the optional SIGUSR2 reload described in
`01-reload.sh`.

## GTK 3 and 4 - `config/gtk-3.0/gtk.css` and `config/gtk-4.0/gtk.css`

```css
@import url("colors.css");
```

Needs `adw-gtk-theme` installed and selected (the reload hook sets
`adw-gtk3-dark`). GTK4/libadwaita apps only read this at startup.

## btop - `~/.config/btop/btop.conf`

```conf
color_theme = "matugen"
```

## hyprlock

Already done: `config/hypr/hyprlock.conf` starts with
`source = ~/.config/hypr/hyprlock-colors.conf`.
