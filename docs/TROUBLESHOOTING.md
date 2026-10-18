# Black screen / no bar

Run **`dot-doctor`** from a terminal inside the session (Super+Return), or from a
TTY (Ctrl+Alt+F3). It is read-only, prints "Likely problems" at the end and saves
a full report to `~/dot-doctor-<time>.txt`.

## Messages that are NOT the problem

These come from Xwayland starting up and are harmless (the text itself says
"not fatal"):

* `The XKEYBOARD keymap compiler (xkbcomp) reports: ... Warning: ...`
* `Unsupported maximum keycode 709, clipping`, `Could not resolve keysym XF86...`

## The one that matters

`KMS: DRM_IOCTL_MODE_CREATE_DUMB failed: Permission denied` (repeating) means a
program could not get a graphics buffer, i.e. it has no working GPU access.
Quickshell (Qt Quick/OpenGL) and wpaperd (EGL) both need that, so the result is
no bar and a black background.

| Cause | Fix |
| --- | --- |
| Running in a VM without 3D acceleration | `touch ~/.config/hypr/software-render`, restart Hyprland (the config does this by itself when `systemd-detect-virt --vm` says you're in a VM). This makes Quickshell use Qt's software renderer. wpaperd has no software mode: enable 3D acceleration in the VM, or use a solid background. |
| Not allowed to open `/dev/dri/renderD*` | `sudo usermod -aG render,video $USER`, log out and back in |
| `qt6-wayland` missing | `sudo pacman -S qt6-wayland` |

## Black wallpaper specifically

wpaperd needs `~/.config/wpaperd/config.toml`. An earlier `install.sh` replaced
the whole `~/.config/wpaperd` directory with a link and moved your own
`config.toml` into the backup. Restore it:

```bash
cp "$(ls -d ~/.config-backup-*/wpaperd/config.toml | tail -1)" ~/.config/wpaperd/config.toml
```

The updated `install.sh` no longer does this: a directory holding files that
aren't in the repo is linked file by file instead.

## Logs

* Quickshell: `~/.cache/quickshell.log`
* Hyprland: `hyprctl rollinglog`
* Hooks: `~/.cache/hooks.log`, `~/.cache/matugen-hook.log`

## Quickshell says "Failed to load configuration"

Run `qs` in a terminal. It prints a chain of `caused by` lines; the **last** one
is the real error, the ones above it just name the files that include it.
Example, fixed in this version:

```
caused by @theme/Colors.qml[65:29]: Cannot assign a value to a signal
```

QML treats any property named `on<Capital>` as a signal handler, so
`onSurface` was rejected. The Material "on-" colours are now `surfaceOn`,
`primaryOn`, ... (`install.sh` replaces an old `Colors.qml` that still has the
old names, keeping a copy in the backup directory).

## Wallpaper is black / "next wallpaper" does nothing

```bash
dot-wallpaper doctor     # explains what's wrong
dot-wallpaper init       # fixes the usual causes
```

wpaperd rotates through the images in the `path` of `~/.config/wpaperd/config.toml`,
and each change runs the `exec` script that regenerates every colour. So:

| Symptom | Cause | Fix |
| --- | --- | --- |
| Changing does nothing | the wallpaper is pinned (picker / `set`): run `dot-wallpaper rotate`; or only one image in the folder | `init` copies six bundled wallpapers into `~/Pictures/Wallpapers` (or add your own) |
| Colours never follow the wallpaper | no `exec =` line in the config | `init` adds it (your config is backed up first) |
| Truly nothing drawn | no config at all, or wpaperd not running | `init` creates it; `setsid -f wpaperd -d` |
| Black in a VM | wpaperd needs OpenGL | see "The one that matters" above |

Keys: `Super+Ctrl+W` next, `Super+Ctrl+Shift+W` previous, `Super+Shift+W` picker. The menu
has Style -> Next/Previous wallpaper, and Setup -> Fix wallpaper.

## "dot-reload is not installed" in the menu

`~/.local/bin` wasn't on the session's PATH. `autostart.lua` now adds it (restart
Hyprland once), and the menu adds it to its own commands as well.

## "Could not register notification server"

Another Quickshell (or mako/dunst) already owns the notification name. Typing `qs`
in a terminal starts a *second* Quickshell. Use `dot-reload shell` to restart it,
and `qs kill` to stop it.

## Scrolling

Mouse-wheel notches and touchpad scrolling both work on the bar widgets
(volume, mic, media, workspaces, calendar months) and in the menu list. Your
touchpad `scroll_factor = 0.2` in `hypr/input.lua` makes touchpad scrolling slow
on purpose; raise it if the bar feels sluggish.

## Scripts aren't executable after unpacking

Some archive tools drop the permission bits. Run `bash install.sh` - it makes
itself and every script executable. (`hyprdot-main.tar.gz` keeps the bits.)

## Right Alt / the Compose key does nothing

```bash
dot-restart-xcompose --check      # or Menu -> Setup -> Check keyboard / Compose key
wev                               # press Right Alt: it should print  sym: Multi_key
```

| `wev` shows | Meaning | Fix |
| --- | --- | --- |
| `Multi_key` | the key is fine | open a **new** terminal (apps read `~/.XCompose` at start), press and release Right Alt, then `m a i l`; or use Super+Space -> Snippets |
| `Alt_R` | the option isn't applied | restart Hyprland (a reload doesn't always rebuild the keyboard) |
| nothing | the key never reaches the session (a VM viewer can grab Right Alt) | `echo compose:rctrl > ~/.config/hypr/compose-key`, restart Hyprland |

The old template used `include "%L"`; if your locale has no Compose table that can
make an app reject the whole file. `dot-restart-xcompose` now writes the explicit
path (or drops the include) so your own sequences always load.

## Stuck keyboard ("only some keys work")

That was the Super+Shift+P / Super+Shift+W **submaps**: while one is active every
other key is swallowed, and nothing showed it. They are gone; the same actions are
ordinary binds now (see `docs/KEYBINDINGS.md`). If a session still feels stuck,
`hyprctl submap` should print `default`.

## Menu: "Setup" / power entries did nothing

* Entries now report back as a notification (done, failed, or "X is not installed").
* `~/.local/bin` is added to the menu's PATH and to the whole session's PATH.
* Log out / Reboot / Shut down used `hyprshutdown`, which most systems don't have;
  `dot-power` falls back to `loginctl` / `systemctl`.
* `dot-doctor` lists every command the menu can run and which are missing.

## New in this version: what needs what

| Feature | Needs | If missing |
| --- | --- | --- |
| Brightness slider | `brightnessctl` and a backlight | hidden (VMs/desktops have none) |
| Wi-Fi tile and list | NetworkManager (`nmcli`) | hidden |
| Bluetooth tile and list | `bluetoothctl` | hidden |
| Stay awake | `hypridle` | tile hidden |
| Power profile | `power-profiles-daemon` | tile hidden |
| Night light | `hyprsunset` | dim icon, says so |
| Clipboard history | `cliphist`, `wl-clipboard` | menu says "cliphist is not installed" |
| Panel blur | a layer rule at the end of `hypr/rules.lua` | panels are translucent but not blurred; check `hyprctl configerrors` |
| Dark/Light, Style | matugen options; if matugen rejects them the hook retries plain | colours still update |

Pinning a wallpaper edits the `path =` line under `[default]`/`[any]` in
`~/.config/wpaperd/config.toml` (backup: `config.toml.dot-backup`) and restarts
wpaperd; `dot-wallpaper rotate` puts the folder back.

## Some apps stay light

```bash
dot-theme init      # writes the Qt config, sets the GTK dark preference
dot-theme doctor    # lists what is missing
```

| App kind | Follows | Needs |
| --- | --- | --- |
| libadwaita / GTK4 | `gsettings color-scheme` | **`dconf`** - without it gsettings forgets the setting at once |
| GTK3 and file dialogs | `adw-gtk3-dark` + `gtk-3.0/settings.ini` | `adw-gtk-theme` |
| Firefox / Chromium | the portal's color-scheme | `xdg-desktop-portal-gtk` |
| Qt | qt5ct/qt6ct with the matugen scheme | `qt5ct` / `qt6ct` |

Apps that were already open keep their old look until restarted.

## kitty / ghostty: black, or "close this window?" prompts

The repo ships `kitty/kitty.conf` and `ghostty/config`: font, padding, translucency, the matugen
colours, and **no confirmation when closing** (`confirm_os_window_close 0`,
`confirm-close-surface = false`). Existing copies are backed up by `install.sh`.

## "Battery low" at every boot or reload

UPower reports 0% for a moment after the shell restarts. The monitor now ignores that (values
must be known, ten seconds old and still low four seconds later) and the hook re-checks the
kernel's own reading and stays quiet for 20 minutes after one warning.

## Workspaces and monitors

`dot-reload` and the bar talk to Hyprland with Lua expressions
(`hyprctl dispatch "hl.dsp.focus({ workspace = 3 })"`), because that is what a Lua config
expects. Each bar highlights the workspace that is active on its own monitor.

## Tray icon right-click does nothing / "Cannot display PlatformMenuEntry"

Quickshell's log says `Cannot display PlatformMenuEntry as quickshell was not started in
QApplication mode.` Tray menus need a QApplication, which `shell.qml` now requests with
`//@ pragma UseQApplication` on its first line (needs `qt6-base`, which is always present
with Quickshell). Restart it once: `dot-reload shell`.

## Media pill missing

The pill only shows while a player reports a track title over MPRIS (Spotify, Firefox/Chromium
tabs, mpv with mpv-mpris, ...). Check with `playerctl -l` and `qs ipc call shell media playpause`.
If the shell fails to load after an update, `qs` in a terminal prints the file and line; the old
widget is `docs/legacy/Media.classic.qml`.

## nmtui (or whiptail) colours are unreadable

nmtui draws with fixed ANSI colour names, and the matugen palette fills nearly every ANSI slot with
a light pastel, so the defaults were pink on pink. `NEWT_COLORS` is now set in `hypr/autostart.lua`
(every terminal, after a Hyprland restart) and in `kitty/kitty.conf` (new kitty windows). Try it
right now in any terminal:

```bash
NEWT_COLORS='root=white,black window=white,black border=lightgray,black shadow=black,black title=blue,black button=blue,black actbutton=black,blue entry=black,lightgray listbox=white,black actlistbox=white,black sellistbox=blue,black actsellistbox=black,blue' nmtui
```

If a colour still looks wrong, edit the value in those two files (names: black red green brown blue
magenta cyan lightgray gray brightred ... white; they are ANSI slots 0-15 of the matugen palette).

nmtui also hard-codes a few colours that `NEWT_COLORS` cannot change (plain labels such as "Please
select an option", error labels, disabled buttons, text boxes). They have their own variable,
`NMT_NEWT_COLORS` (`plainLabel`, `badLabel`, `disabledButton`, `textboxWithBackground`), set in the
same two files. Check that both variables reached your terminal with `echo "$NEWT_COLORS"; echo "$NMT_NEWT_COLORS"`;
if they are empty, that terminal was started before the change - open a new one (kitty) or restart
Hyprland (other terminals).

## Only one file manager window opens

Nautilus is single-instance, so a bare `nautilus` just re-activates the running one.
`Super+E` now runs `nautilus --new-window`.

## Log out / Reboot / Shut down need Enter twice

That is deliberate: they ask "Enter again to confirm" (red, on the row) so a stray key can't
end your session. Moving to another row cancels it; Esc cancels it. To run them on the first
Enter, set `confirmPower: false` in `config/quickshell/theme/Style.qml` and `dot-reload shell`.
(Older versions also cancelled the confirmation whenever the mouse moved a few pixels, which made
clicking Log out start over forever - fixed.)

## "Failed to start Samba AD Daemon" after logging out

Not from these dotfiles (nothing here starts or mentions Samba). `samba.service` is the Samba
*Active Directory domain controller*; if it is enabled and not configured as one it fails at
boot, and the `[FAILED]` line stays on the console, so you see it as soon as you log out to the
TTY. Check, then switch it off if you don't run a domain:

```bash
systemctl --failed
systemctl status samba
sudo systemctl disable --now samba     # file sharing uses smb + nmb, not this one
```

`dot-doctor` now lists failed services. Logout also ends only your current session
(`loginctl terminate-session`) instead of `terminate-user`, which killed every session and
service you own.
