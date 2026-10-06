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
| Changing does nothing | only one image in the configured folder | `init` copies six bundled wallpapers into `~/Pictures/Wallpapers` (or add your own) |
| Colours never follow the wallpaper | no `exec =` line in the config | `init` adds it (your config is backed up first) |
| Truly nothing drawn | no config at all, or wpaperd not running | `init` creates it; `setsid -f wpaperd -d` |
| Black in a VM | wpaperd needs OpenGL | see "The one that matters" above |

Keys: `Super+Ctrl+W` next wallpaper, or `Super+Shift+W` then `l` / `h`. The menu
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
