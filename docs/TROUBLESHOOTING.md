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

## Media icon / card missing

The bar icon and the Quick settings card only show while a player reports a track title over MPRIS (Spotify, Firefox/Chromium
tabs, mpv with mpv-mpris, ...). Check with `playerctl -l` and `qs ipc call shell media playpause`.
If the shell fails to load after an update, `qs` in a terminal prints the file and line.

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

## "Power profile failed ... invalid choice: 'performance'"

`power-profiles-daemon` only offers `performance` when your CPU/platform driver supports it; many
desktops and VMs have just `power-saver` and `balanced`. The tile used to cycle through all three
anyway. It now reads the real list (`powerprofilesctl list`) and cycles only through what exists
(and is hidden when fewer than two profiles are available). Check yours: `powerprofilesctl list`.

## No bar / menu after editing the QML

```bash
dot-check --live          # file:line:col of what is wrong (and Lua / JSON problems)
dot-reload shell          # restarts only if the check passes
```

If the new config does not load, `dot-reload` starts the last config that did
(`~/.cache/quickshell-lkg`) and says so; fix the error and run `dot-reload shell` again. To
run the old copy by hand: `quickshell -p ~/.cache/quickshell-lkg`.

## No Wi-Fi / Bluetooth tile in Quick settings

Run `dot-doctor` and read the "bluetooth / network hardware" section: it says which of these applies.
Those tiles only appear when the hardware exists: a Wi-Fi tile needs a Wi-Fi adapter (`nmcli device
status` lists one as type `wifi`), a Bluetooth tile needs an adapter BlueZ knows about
(`bluetoothctl list`). A VM or a desktop usually has neither. A machine with no Wi-Fi adapter gets an
**Ethernet** tile instead: it shows the wired connection and a click opens nmtui. The bar's network
icon: left click = Quick settings, right click = nmtui.

If Bluetooth hardware exists but there is no tile: `pacman -S bluez bluez-utils` and
`sudo systemctl enable --now bluetooth` (Arch does not start the service by default), then check
`bluetoothctl list` shows a controller and `rfkill list bluetooth` is not "Hard blocked". The shell
notices within a minute (or at once when Quick settings opens); it no longer needs a restart.

## Wallpaper change flashes / "wpaperd restarted"

wpaperd ignores an edited `path` until told to redraw (upstream issue #201), so this script used to
kill and restart it on every change. It now runs `wpaperctl set-wallpaper <image>` (pinning) or
`wpaperctl next-wallpaper` (`dot-wallpaper rotate`) and restarts wpaperd only if that fails. Check
that wpaperctl has them: `wpaperctl --help | grep -E 'set-wallpaper|next-wallpaper'`.

## The lock screen is heavy / slow to appear

The normal lock screen blurs a screenshot of your desktop in 3 passes. In a VM, or on a weak GPU, that
is drawn on the CPU. `dot-lock` (used by Super+L and hypridle) therefore starts
`hypr/hyprlock-low.conf` (a solid colour) there. If hyprlock rejects that file it falls back to the
normal lock screen, so the machine never stays unlocked. Force it with
`touch ~/.config/hypr/low-effects`, or keep the full one with `touch ~/.config/hypr/full-effects`.

## Hyprland uses a lot of CPU (especially in a VM)

`dot-doctor` -> "power & suspend" -> "busiest processes". If `Hyprland` itself is at 50-150% while
you are idle, it is drawing blur, shadows and animations on the CPU. That happens in a VM without 3D
acceleration (`virtualisation: kvm` plus `failed to create dri2 screen` in the Quickshell log), or
with a very weak GPU. `hypr/looknfeel.lua` now switches those effects off automatically when
`systemd-detect-virt` reports a VM. Force it on or off with an empty marker file, then `dot-reload hypr`:

```bash
touch ~/.config/hypr/low-effects     # no blur / shadows / animations
touch ~/.config/hypr/full-effects    # keep them even in a VM
hyprctl getoption decoration:blur:enabled     # check what is active
```

The real fix in a VM is 3D acceleration (virtio-gpu with virgl, or GPU passthrough).

## btop / nmtui / pavucontrol / the updater float but are small

Hyprland's Lua config does **not** understand percentage sizes like `size = "60% 70%"` (that was the
old hyprlang syntax). Such a rule is silently ignored and the window keeps its default size
(kitty: 640x400 px). `size` needs numbers or expressions; `hypr/rules.lua` has a `pct(w, h)` helper
that produces `{ "(monitor_w*0.w)", "(monitor_h*0.h)" }`, and `dot-check` fails if a percentage
size sneaks back in. To change a window's size edit its numbers, e.g. `float_tool("btop", 96, 92)`
(96% x 92% of the monitor's logical size = resolution / scale).

After editing: `hyprctl reload`, then reopen the window (rules apply when a window opens).
Useful when something is off:

```bash
hyprctl configerrors                            # Lua errors in the config
hyprctl clients | grep -B3 -A14 "dot-btop"      # class: dot-btop, floating: 1, size: W,H
hyprctl monitors | grep -E "Monitor| at |scale" # logical size = resolution / scale
```

## btop shows its default colours

`btop.conf` must say `color_theme = "matugen"`. `dot-theme init` writes that now (close btop first,
it rewrites its config on exit); `dot-theme doctor` tells you which part is missing, including the
generated theme file itself (it appears after the first wallpaper change, `Super+Ctrl+W`).

## Fans loud, machine hot, or fans not following the temperature

```bash
dot-thermal doctor     # sensors, fan modes, power policy, services, busy processes -> "Likely problems"
dot-thermal setup      # installs/enables power-profiles-daemon (+ thermald on Intel); asks first, --dry-run to preview
dot-thermal watch      # live temperature / RPM / frequency while you test
```

On most laptops the firmware runs the fan curve itself; Linux only chooses a policy. What this repo
was missing was the policy layer, so the usual causes are:

| Finding | Meaning | Fix |
| --- | --- | --- |
| power-profiles-daemon not installed/running | nothing manages the CPU power state or platform profile; the Quick settings power tile is hidden | `dot-thermal setup` |
| thermald missing (Intel only) | no gentle thermal limiting before the hard throttle | `dot-thermal setup` |
| platform profile or ppd = `performance` | hotter and louder on purpose | `powerprofilesctl set balanced` |
| fan `pwmN_enable` = 1 with no fan controller, or 0 | a tool left the fan fixed / at full speed | `dot-thermal setup` (writes 2 = automatic) or reboot |
| tlp or auto-cpufreq AND power-profiles-daemon | they overwrite each other | keep one: `sudo systemctl disable --now tlp` |
| a process using most of a core | the fan is answering real load | `btop`, close or fix it |
| throttle events since boot | cooling can't keep up | dust, thermal paste, fan curve |
| discrete GPU awake, driving no monitor | a dGPU that never sleeps is a common heat/fan/battery drain on hybrid laptops (it is *expected* while it drives an HDMI/DP monitor: `doctor` says so and does not flag that) | `doctor` names the process holding it; for Hyprland itself put the integrated GPU first with `AQ_DRM_DEVICES=/dev/dri/by-path/pci-<addr>-card` (`doctor` prints your path) in `hypr/autostart.lua`, restart Hyprland |
| GPU `power/control` = on, or clocks forced (`power_dpm_force_performance_level` not `auto`) | the GPU can't sleep / is held at high clocks | `echo auto \| sudo tee <the file doctor prints>`, then find what set it (tlp, corectrl, a udev rule) |
| no fan sensor at all | usually fine (firmware controls it); a model driver may be needed for control | see the hint `doctor` prints (thinkpad_acpi, dell-smm-hwmon, asus-nb-wmi, nbfc-linux) |

In a VM it says so and stops: the fans belong to the host.

### Battery charge limit

If you are plugged in most of the time, keeping the battery at 100% wears it faster. Cap it:

```bash
dot-thermal battery          # show the current limit (and whether this laptop supports one)
dot-thermal battery 80       # stop charging at 80% (allowed: 50-100); asks, uses sudo
dot-thermal battery off      # back to 100%
```

This writes `charge_control_end_threshold` and installs `dot-charge-limit.service`, so the limit is
re-applied at boot and after suspend/hibernate (some firmware forgets it). Menu: Setup -> Battery.
A battery already above the limit stays there until it discharges. If `dot-thermal battery`
says the limit is "not exposed", this kernel/firmware has no such control: look for "battery care",
"battery health" or "conservation mode" in the BIOS/UEFI or the vendor's tool. Some laptops only
accept fixed values (often 60/80/100); the command warns when the kernel refuses one.

## Suspend / idle uses a lot of power

First find out WHICH problem you have:

1. **The machine is awake and idle but busy** (fans, battery): `dot-doctor` -> "power & suspend" lists
   the busiest processes. Note that out of the box hypridle only dims and locks; it never turns the
   screen off or suspends (see the two OPTIONAL blocks at the end of `hypr/hypridle.conf`), so a locked
   laptop keeps its display on.
2. **It really suspends but the battery drains**: `dot-sleep-log report` (recorded automatically on
   every suspend) prints `battery 90% -> 66% ... = 3.0 %/h`. Under ~1 %/h is healthy. If it is
   higher, the "power & suspend" section shows the likely reasons: `mem_sleep` showing only
   `[s2idle]` (no `deep`), `suspend_stats/last_hw_sleep` being 0 (the hardware never reached sleep),
   a discrete GPU whose `runtime_pm` stays `active`, or inhibitors.
3. **The suspend itself fails or hangs**: `suspend_stats/fail` and `last_failed_dev` name the device.

Also fixed in this version: `hypridle.conf` called `hyprctl dispatch dpms on`, which on Hyprland
0.55+ (Lua config) is a syntax error that does nothing; it now uses
`hyprctl dispatch 'hl.dsp.dpms({action = "on"})'`.

## What does install.sh do? (copy vs link)

By default it **copies**: `config/<app>/...` -> `~/.config/<app>/...`, `bin/*` -> `~/.local/bin`, and
the helper files (`tools/`, `docs/`, `wallpapers/`, `VERSION`) -> `~/.local/share/hyprdot`. After that
the repo folder can be moved or deleted. Things it does NOT overwrite: matugen's generated colour
files and the GTK/Qt settings (seeded once), and anything that is not part of the repo (your
`wpaperd/config.toml`, `xcompose/vars`, files you added).

Re-running it updates: a file that still equals what was installed is replaced silently; one you
edited is moved to `~/.config-backup-<time>/` first; one the repo dropped is removed only if you
never touched it. The record lives in `~/.local/share/hyprdot/manifest`.

An older install made **symlinks** into the repo (that is why `dot-doctor` warned about a repo in
Downloads). Running the new `install.sh` once converts them: each link is moved to the backup and
replaced by a real file. `bash install.sh --link` still gives the symlink behaviour for developing.

## Only one file manager window opens

Nautilus is single-instance, so a bare `nautilus` just re-activates the running one.
`Super+E` now runs `nautilus --new-window`.

## Log out / Reboot / Shut down need Enter twice

That is deliberate: the first Enter (or click) turns the row red and says "Press again to confirm", so a
stray key can't end your session. (Older versions never showed that hint - a bug in how the row was
compared with the pending action - so it just seemed to need two presses for no reason.) Moving to another row cancels it; Esc cancels it. To run them on the first
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

## Terminal text is too faint to read

`dot-contrast --check` prints every ANSI colour's contrast against the background. After each
wallpaper change the hook runs `dot-contrast`, which lightens (dark scheme) or darkens (light
scheme) only the colours below 4.5:1 (colour 8: 3:1). Run it by hand to re-apply: `dot-contrast`.

## Panels feel slow to open

`dot-perf` times every panel and shows which GPU Hyprland and Quickshell render on. Panels animate
in QML (130 ms in, 80 ms out); Hyprland's own layer animations are off on purpose (`hypr/looknfeel.lua`),
and `ignore_alpha` in `hypr/rules.lua` keeps the dimming scrim from triggering a full-screen blur.
`touch ~/.config/hypr/low-effects` turns blur, shadows and animations off to test.

## Different wallpaper on each monitor

wpaperd chooses an image per display when its config points at a folder, and then only one display
drives the colours. The config now points at ONE image and `dot-wallpaper` changes it for all
displays (next/prev, the picker, and the `daemon` timer behind `dot-wallpaper rotate [minutes]`).
An old folder config is converted at the next login; to do it now: `dot-wallpaper sync`.
`dot-wallpaper doctor` warns while a folder path is still configured. Picking a wallpaper in the
picker pins it (automatic changes off); `dot-wallpaper rotate` turns them back on.

## The screen stays on when idle or locked

`hypr/hypridle.conf` now dims at 3 min, locks at 5, suspends at 10 min on battery and at 20 min on
mains power (`dot-power idle-suspend`). The word in `~/.config/hypr/idle-action` picks what happens:
`suspend` (default), `hibernate`, `suspend-then-hibernate` or `none`. Hibernate needs swap and a
`resume=` kernel setup; when `systemctl can-hibernate` is not "yes" it suspends instead. If you edited
your own `hypridle.conf`, the installer keeps it: copy the two `idle-suspend` listeners from the repo
copy (`~/.local/share/hyprdot/` has none; see `config/hypr/hypridle.conf` in the checkout), then
`pkill hypridle; hypridle &`. Check it works: `dot-power idle-suspend any` suspends right now.
Turning the panel off while merely locked (DPMS) is still the commented OPTIONAL block there: it is
the part of Hyprland most likely to misbehave with an external monitor.
