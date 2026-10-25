# Improvements and ideas

Written from what actually went wrong or looked wrong while working on this repo, not from a
generic wish list. **Effort**: S = under an hour, M = a few hours, L = a weekend.
**Confidence** says how sure I am the idea works as described; anything marked *needs testing*
depends on behaviour I could not run here (there was no Hyprland or Quickshell to try it on).

## 1. Reliability - make breakage impossible or at least obvious

**Status (version 2026-10-19.2): items 1-5 are done, 6 exists as an experimental option. Item 4 is now mostly moot: the installer copies by default, so nothing depends on where the repo lives (the warning remains for `--link`). Still missing: `install.sh --uninstall`.**
1 = `dot-check` + the safety net in `dot-reload`; 2 = `tests/` and `.github/workflows/check.yml`;
3 = power profiles and the Wi-Fi tile (see `docs/TROUBLESHOOTING.md`); 4 = `install.sh` and
`dot-doctor` warn about Downloads/tmp; 5 = `dot-reload` trims `quickshell.log` to its last 64 KB;
6 = `dot-check --load`, untested against real Quickshell. Still *untested on real tools*: `qmllint`,
`shellcheck` and `luac` integration (none were installed where this was built).

| # | Idea | Why (evidence) | Effort |
| --- | --- | --- | --- |
| 1 | **A safety net for the shell.** `dot-reload shell` first checks the QML (`qmllint` when installed, plus the static reference check used while developing), keeps a copy of the last config that loaded, and restores it if the new one fails to start. | One QML syntax error means no bar, no menu, no notifications. It happened with an old `Tile.qml` (`Expected token ':'`) and could happen with any edit. | M |
| 2 | **CI on every push.** `bash -n` and `shellcheck` on `bin/*` and hooks, `luac -p` on the Hyprland Lua, `qmllint` on QML, JSON validation for `menu.json`, and a check that every `Colors.*` / `Style.*` / singleton member used actually exists. | All of these failure classes were found by hand in this session. | S-M |
| 3 | **Never assume hardware.** Audit every Quick settings tile for the "performance profile" mistake: the tile cycled three hard-coded profiles and `powerprofilesctl` rejected `performance` on a machine whose driver does not offer it (fixed). Same pattern for brightness, Bluetooth, Wi-Fi: ask what exists, then show it. | `Power profile failed ... invalid choice: 'performance'`. | S |
| 4 | **Warn about fragile install locations.** `install.sh` symlinks into the checkout, so a repo in `~/Downloads` or `/tmp` breaks everything when it is cleaned. Warn, and offer to move it to `~/.dotfiles`. | Your links pointed into `~/Downloads/hyprdot-main`. Two reports came from a mix of old and new copies (fixed by the VERSION line in `dot-doctor`). | S |
| 5 | **Rotate `~/.cache/quickshell.log`.** It is appended to forever. | The doctor used to report errors from runs long since fixed (now only the current run counts). | S |
| 6 | **Headless load test.** Try starting Quickshell with `QT_QPA_PLATFORM=offscreen` in CI and fail if the log says "Failed to load configuration". | Catches what static checks cannot. *Needs testing: I do not know whether the offscreen platform works with layer-shell windows.* | M |

## 2. Performance

**Status (2026-10-20.1): this section is done.**
7 = network (`nmcli monitor`) and Bluetooth (BlueZ signals over `dbus-monitor`) are event-driven, everything
else is a slow poll plus a refresh whenever Quick settings opens; 8 = the theme hook skips unchanged
work; 9 = `dot-wallpaper` no longer restarts wpaperd (`wpaperctl set-wallpaper` / `next-wallpaper`; the
restart is the fallback). Also done along the way: automatic low-effects mode for VMs (confirmed working
on a real VM), a light lock screen (`dot-lock`), a corrected `hypridle.conf`, and `dot-sleep-log`.
Not confirmed on real hardware yet: that `dbus-monitor --system` may receive BlueZ signals without root
(if not, the 60 s poll covers it), that `nmcli monitor` delivers, and `hyprlock -c`.

| # | Idea | Why | Effort |
| --- | --- | --- | --- |
| 7 | **Events instead of polling.** Wi-Fi, Bluetooth, brightness, power profile, night light and stay-awake are still polled (every 20-30 s, faster while Quick settings is open). Quickshell has native Bluetooth, UPower and PipeWire services, and `nmcli monitor` can feed the network state. | Every poll starts a process. Native services are push-based and cheaper. *Needs testing: check each API against the installed Quickshell version.* | M |
| 8 | **Do not reload all of Hyprland per wallpaper change.** `01-reload.sh` runs `hyprctl reload` and toggles the GTK theme each time. | A full reload is the heaviest step of a wallpaper change and the GTK toggle can flicker open apps. Apply only the border colours, and only toggle GTK when light/dark changes. *Needs testing.* | M |
| 9 | **Do not restart wpaperd on every pick.** `dot-wallpaper set` kills and restarts it. | Causes a brief flash; wpaperd already reloads its config when the file changes. *Needs testing.* | S |

## 3. Look and feel

| # | Idea | Why | Effort |
| --- | --- | --- | --- |
| 10 | **One global UI scale.** Sizes are fixed pixel constants (bar 34, fonts 13-14, icons 16, card widths 360-420). Add `Style.scale` and multiply, ideally tied to the monitor scale. | "Everything looks tiny" came up first and was fixed by editing many numbers. A single knob would have been one edit. | M |
| 11 | **A proportional UI font.** The whole shell is monospace, which makes labels wide (the media pill needed a width budget, "Wallpapers" did not fit its tile). Keep mono for clocks and numbers. | Several truncation bugs came from monospace widths. | S |
| 12 | **Optional floating-islands bar.** Left, centre and right groups as separate rounded pills, matching the media pill. | The pill looks more polished than the flat bar around it. A style choice: only if you like it. | M |
| 13 | **Notification upgrades.** Action buttons, grouping per app, history that survives a shell restart, per-app Do Not Disturb. | Notifications are basic: last ten, in memory. | M |
| 14 | **More Quick settings:** VPN, screen recording, microphone-in-use indicator. | Common needs not covered. | M |
| 15 | **Screenshot follow-up.** Notification actions: open, edit, copy path. | Today it only says "saved". | S |
| 16 | **A keybind cheat sheet** generated from `bindings.lua` and shown in the menu, plus a duplicate-bind check. | `KEYBINDINGS.md` is written by hand and can drift. | M |

## 4. Theming

| # | Idea | Why | Effort |
| --- | --- | --- | --- |
| 17 | **Fix the terminal palette at the source.** The kitty/ghostty templates put light pastels in almost every ANSI slot, so any program using ANSI colours can come out unreadable: nmtui measured 1.00:1 contrast. The `NEWT_COLORS` / `NMT_NEWT_COLORS` settings are a workaround for one program. Generate ANSI 0-7 so they contrast with the background, or at least add a contrast check to `dot-theme doctor`. | nmtui; btop, htop, git diff and others are likely affected. | M |
| 18 | **`dot-theme init` respects light mode.** It forces the dark preference and writes a new Qt config backup on every run. | Seen when reading the script. | S |
| 19 | **More app templates** (Firefox, VS Code, Discord, Zathura) - matugen supports them. | Apps outside the current list stay un-themed. | S each |

## 5. Housekeeping

| # | Idea | Why | Effort |
| --- | --- | --- | --- |
| 20 | **Remove dead code:** the `scrolling` layout helpers in `bindings.lua` and the `scrolling` block in `looknfeel.lua` (workspace 2 no longer uses it), `docs/legacy/Media.classic.qml` once you are happy with the pill, leftover "ML4W" headings. | Less to read and break. | S |
| 21 | **A real README:** screenshots, a requirements table per feature, an update procedure, `install.sh --uninstall`. | The README is a command list. | S |
| 22 | **A CHANGELOG** next to `VERSION`. | Doctor reports now show which copy is installed; they should also say what changed between copies. | S |
| 23 | **VM fallback for wallpapers.** wpaperd needs OpenGL. When software rendering is detected, use a CPU-only wallpaper tool. | The VM reports in this session had no usable GPU. *Needs testing in a VM.* | M |
| 24 | **Other distros.** `install.sh` installs packages on Arch only; add Debian/Fedora package lists. | `dot-updates` already knows six distros; the installer does not. | M |

## Not verified in this session

These are fixes I made without being able to see the result; treat them as "probably right":

* The file-dialog size rule matches the window class `xdg-desktop-portal-gtk` (or the newer
  `org.freedesktop.impl.portal.desktop.*`). If dialogs are still full height, run
  `sleep 5; dot-doctor` and open one: the "windows" section shows the real class.
* `NMT_NEWT_COLORS` key names: `plainLabel` is confirmed from NetworkManager's merge request;
  `badLabel`, `disabledButton` and `textboxWithBackground` follow the same pattern but were not
  checked. An unknown key should simply be ignored.
* The media pill, Quick settings tile centring and the polling changes were checked statically
  (brackets, ids, references) but not run on a real Quickshell.
