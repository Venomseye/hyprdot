# Quickshell shell (replaces Waybar, Rofi and Mako)

Needs Quickshell 0.2 or newer (the `import qs.<dir>` module imports), `upower`
(battery), PipeWire/WirePlumber (audio, OSD), `JetBrainsMono Nerd Font`.
Optional: `nmcli` (network icon), `bluetoothctl` (bluetooth icon), `hyprsunset` (night light),
`pacman-contrib` on Arch (accurate update counts; `dot-updates` falls back to a possibly stale count without it).
Stop mako/dunst first - only one daemon can own `org.freedesktop.Notifications`.

```
config/quickshell/
  shell.qml                entry point + the `shell` IPC target
  theme/    Colors.qml     matugen output (placeholder until the first wallpaper change)
            Style.qml      sizes, font, radii - change look here
            Txt.qml        text with the shell font/colour
  bar/                     Bar + one file per widget (+ calendar popup)
  menu/     MenuPanel.qml  the Super+Space menu
            menu.json      its commands - edit freely
            Fuzzy.js       search scoring
  notifications/           daemon, banners, history, Do Not Disturb
  osd/                     volume OSD
  services/                ShellState (persisted), Battery, BatteryMonitor,
                           NightLight (hyprsunset), UpdateCheck (dot-updates)
```

## Using it

| Do | Result |
| --- | --- |
| `Super+Space` | menu: type to search apps *and* commands (fuzzy, or initials: `sd` = Shut Down); Enter runs; Enter on a category opens it; Backspace goes back; **Esc closes** (so does a click outside, or 30 s without use). Long lists scroll: arrows, mouse wheel, PageUp/PageDown. Log out / Reboot / Shut down ask for a second Enter. Setup/wallpaper commands report success or failure as a notification |
| `Super+Shift+P` | the menu, opened straight into System (lock, suspend, log out, reboot, shut down) |
| `Super+N` / `Super+Shift+N` | notification history (last ten; Esc / click outside / 15 s closes it) / Do Not Disturb |
| notifications | disappear after 5 s (critical ones 12 s); hover pauses, click dismisses |
| clock: left | calendar (Esc, a click outside or 15 s closes it) |
| menu -> Snippets / Emoji | copies text from `~/.config/xcompose/vars` (or an emoji) to the clipboard - paste with Ctrl+V |
| bar: double-click empty space | toggle bar transparency |
| clock: left / right click | calendar with ISO weeks / cycle the format |
| menu button: left / right | menu / terminal |
| media: left / middle / scroll | play-pause / next / previous-next |
| updates: left / right | run the updater in a terminal / check now. Dim check = up to date, arrow + count = updates waiting, red triangle = check failed |
| night light: left | toggle hyprsunset (moon = on, sun = off, dim = not installed; temperature in `theme/Style.qml`) |
| microphone: left / scroll | mute-unmute (red slashed icon = muted) / input volume |
| audio: scroll / right / left | volume (OSD appears) / mute / pavucontrol |
| battery: right / left | show-hide percentage / btop |
| bluetooth: right / left | radio on-off / blueman |
| tray | hover the chevron to reveal the icons |

IPC: `qs ipc call shell toggle menu|history|dnd|transparency|nightlight`, `qs ipc call shell menu System`, `qs ipc call shell refresh updates`,
`qs ipc call shell show|hide menu|history`, `qs ipc call shell ping`.

## Customising

* Your own menu entries: create `~/.config/quickshell/menu.user.json`, same format
  as `menu/menu.json` (`title`, `glyph`, `subtitle`, then `action` or `children`).
  It is appended to the top level and reloads when saved.
* Look: `theme/Style.qml` (bar height 26, radius 10, menu radius 12, font).
* Persisted toggles live in `~/.local/state/quickshell-dot/state.json`.
* After editing QML, `dot-reload shell` restarts it (symlinked files may not
  trigger Quickshell's own live reload).

## Not implemented (Omarchy has these)

Draggable bar position and vertical bars, the plugin/`shell.json` system, the
bluetooth/network/audio popup panels (these open your existing tools instead),
the built-in lock screen (hyprlock/hypridle are used), polkit agent, and the
theme switcher.

## Updates on other distros

`bin/dot-updates` reads `/etc/os-release` and uses: `checkupdates` (+ `yay`/`paru`
for the AUR) on Arch and derivatives, `apt` on Debian/Ubuntu/Mint, `dnf` on
Fedora/RHEL, `zypper` on openSUSE, `xbps-install` on Void, `apk` on Alpine. On
anything else the updates icon hides itself. Try it by hand: `dot-updates`,
`dot-updates --cmd`, `dot-updates --distro`.
