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
| `Super+Space` | menu: type to search apps *and* commands (fuzzy, or initials: `sd` = Shut Down); Enter runs; Enter on a category opens it; Backspace goes back; **Esc steps back** (clears the search, leaves the category, closes at the top; a click outside or 30 s without use closes it). Long lists scroll: arrows, mouse wheel, PageUp/PageDown. Log out / Reboot / Shut down ask for a second Enter. Setup/wallpaper commands report success or failure as a notification |
| `Super+Shift+P` | the menu, opened straight into System (lock, suspend, log out, reboot, shut down) |
| `Super+N` / `Super+Shift+N` | notification history (last ten; Esc / click outside / 15 s closes it) / Do Not Disturb |
| notifications | disappear after 5 s (critical ones 12 s); hover pauses, click dismisses |
| clock: left | calendar (Esc, a click outside or 15 s closes it) |
| menu -> Snippets / Emoji | copies text from `~/.config/xcompose/vars` (or an emoji) to the clipboard - paste with Ctrl+V |
| bar: double-click empty space | toggle bar transparency |
| clock: left / right click | calendar with ISO weeks / cycle the format |
| menu button: left / right | menu / terminal |
| media: buttons / click / right-click | previous, play-pause, next buttons; click the pill = play-pause; right-click = next (see "Media player" below) |
| updates: left / right | run the updater in a terminal / check now. Hidden while up to date; arrow + count = updates waiting, red triangle = check failed |
| night light: left | toggle hyprsunset (moon = on, sun = off, dim = not installed; temperature in `theme/Style.qml`) |
| microphone: left / scroll | mute-unmute (red slashed icon = muted) / input volume |
| audio: scroll / right / left | volume (OSD appears) / mute / pavucontrol |
| battery: right / left | show-hide percentage / btop |
| bluetooth: right / left | radio on-off / blueman |
| tray | hover the chevron to reveal the icons |
| any bar icon | hover for a moment: tooltip with the current state and the click actions |
| sliders icon / `Super+A` | quick settings: volume, mic, brightness sliders; Wi-Fi, Bluetooth, DND, night light, stay-awake and power-profile tiles; lists to switch audio output, join Wi-Fi, connect Bluetooth devices (lists scroll inside a fixed height; the whole panel scrolls if the screen is short) |
| `Super+Shift+W` | wallpaper picker: thumbnails, arrows + Enter or click to apply; just type to filter by name (Esc clears it, then closes); Random applies a random one; Dark/Light and Style change the matugen scheme; "Rotate all" resumes rotation after pinning one |
| `Super+V` / `Super+C` | clipboard history / calculator, both inside the menu |
| menu: mouse vs keyboard | the highlight follows whichever you used last; a menu opening under a resting pointer is not hijacked |

IPC: `qs ipc call shell media playpause|play|pause|stop|next|previous`, `qs ipc call shell toggle menu|history|dnd|transparency|nightlight`, `qs ipc call shell menu System`, `qs ipc call shell refresh updates`,
`qs ipc call shell show|hide menu|history`, `qs ipc call shell ping`.

## Media player

The bar shows a pill whenever something is playing (it shortens its text to fit between the
workspaces and the clock): the cover, "title - artist" and previous / play-pause / next buttons.
Clicking the pill toggles play/pause, right-click skips to the next track; the scroll wheel does
nothing. There is deliberately no player popup or seek bar.

* Which player: a playing one, else the first. The media keys use the same choice
  (`qs ipc call shell media ...`, falling back to `playerctl` when the shell is down), and
  `playerctld` is no longer started - its proxy player only filled the Quickshell log with
  `NoActivePlayer` warnings.
* Code: `services/NowPlaying.qml` (state) and `bar/Media.qml` (the pill). The previous one-line
  widget is kept as `docs/legacy/Media.classic.qml`; to go back:
  `cp docs/legacy/Media.classic.qml config/quickshell/bar/Media.qml && dot-reload shell`.

## Performance notes

* **Events instead of polling.** Network state follows `nmcli monitor` and Bluetooth follows BlueZ's
  D-Bus signals (`dbus-monitor`), so a change shows at once. The poll that remains is only a safety
  net: 60 s, or 10 s while Quick settings is open. Brightness, power profile, night light and stay
  awake only change when you change them (or rarely, from outside), so they are checked every 90 s
  and immediately whenever Quick settings opens.
* **Wallpaper changes no longer restart wpaperd.** `dot-wallpaper set/next/prev` tell the running
  wpaperd with `wpaperctl set-wallpaper`, and `rotate` with `wpaperctl next-wallpaper`; only an older
  wpaperd, or one that is not running, still gets restarted (that was a new process and a flash on
  every change). The theme hook also skips the Hyprland reload and the GTK refresh when the generated
  colours and light/dark mode are unchanged.
* **Low-effects mode.** In a VM (or with `~/.config/hypr/low-effects`) blur, shadows and animations are
  off and the lock screen is a solid colour (`dot-lock`, `hypr/hyprlock-low.conf`): they are drawn on
  the CPU there. `~/.config/hypr/full-effects` turns the full look back on.
* Nothing in the bar animates while a track plays, so it does not keep redrawing.

## Customising

* Your own menu entries: create `~/.config/quickshell/menu.user.json`, same format
  as `menu/menu.json` (`title`, `glyph`, `subtitle`, then `action` or `children`).
  It is appended to the top level and reloads when saved.
* Look: `theme/Style.qml` (bar height 34, gap 10, radius 10, menu radius 12, font).
* Persisted toggles live in `~/.local/state/quickshell-dot/state.json`.
* After editing QML, `dot-reload shell` restarts it. Edit the live files in `~/.config/quickshell`
  (Quickshell reloads them as you save), or edit the repo and run `bash install.sh` again - your
  edited copies are backed up before being replaced.

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
