# hyprdot

Hyprland + Quickshell dotfiles with wallpaper-driven colours (matugen). Everything is generated from
one wallpaper: the bar, menu, notifications, terminals (kitty, ghostty), btop, GTK and Qt apps.

**What you get:** a Quickshell bar (3 styles: classic, floating, islands), an app/command menu
(`Super+Space`), quick settings with a now-playing card (`Super+A`), a wallpaper picker, notification
history with action buttons, clipboard history, calculator, a keybind panel (`Super+/`), screenshots
with Open/Edit/Copy-path buttons, a lock screen, and fast animations tuned for real hardware.

**Needs:** Hyprland (0.55+ with the Lua config), Quickshell 0.2+, matugen, wpaperd, qt6-wayland. On Arch,
`install.sh --with-deps` installs these and the optional programs; each optional feature hides itself
or says what is missing (see `docs/TROUBLESHOOTING.md`, "what needs what").

```bash
bash install.sh              # COPIES config/ -> ~/.config and bin/ -> ~/.local/bin (backs up what you changed)
bash install.sh --with-deps  # ...and installs the programs the keybinds/menu launch (Arch)
bash install.sh --dry-run    # show what it would do, change nothing
bash install.sh --link       # symlink instead of copying (for developing inside this folder)
bash install.sh --uninstall  # remove what was installed (files you edited are kept)
```

`bash install.sh` also makes every script executable, so it works even if your
archive tool dropped the permission bits (use `hyprdot-main.tar.gz` to keep them).

After a normal (copy) install nothing depends on this folder: move or delete it. To update, unpack
a newer version and run its `install.sh` again: files you edited are moved to
`~/.config-backup-<time>/` first, files you did not touch are simply updated.

On Arch it offers to install missing core packages (pacman, then an AUR helper -
building `yay` for you if you have none). Restart Hyprland afterwards.

| Tool | What it does |
| --- | --- |
| `dot-reload [hypr\|shell]` | reload Hyprland / restart Quickshell without stray processes |
| `dot-wallpaper next\|prev\|rotate [MIN]\|sync\|doctor\|init` | change wallpaper (the same image on every monitor), automatic changes, fix "black wallpaper / nothing changes" |
| `dot-updates` | pending updates for the bar (Arch, Debian, Fedora, openSUSE, Void, Alpine) |
| `dot-power lock\|suspend\|logout\|reboot\|shutdown` | session actions with fallbacks (used by the menu and `Super+L`) |
| `dot-snippets` | text/emoji snippets for the menu (clipboard based) |
| `dot-clip` | clipboard history entries for the menu (cliphist) |
| `dot-screenshot screen\|all\|region\|window [--edit]` | screenshots: active display, everything, selection, window |
| `dot-theme init\|doctor` | make GTK and Qt apps follow dark mode and the wallpaper colours |
| `dot-thermal doctor\|status\|watch\|setup\|battery` | fans, temperatures, GPU and power policy: why are the fans loud or not following the temperature; `setup` installs/enables power-profiles-daemon (+ thermald on Intel); `battery 80` caps charging at 80% |
| `dot-doctor` | read-only diagnosis of black screen / no bar / keyboard / menu commands |
| `dot-contrast [--check]` | lighten/darken terminal ANSI colours that are too faint to read (runs after every wallpaper change) |
| `dot-keys [--check]` | every keybind, read live from `hypr/bindings.lua` (`Super+/`, or menu -> Keybinds, shows them as tiles); `--check` finds keys bound twice |
| `dot-ui-scale [N\|reset]` | make the whole shell bigger/smaller (0.75-2.0; menu -> Style -> UI size) |
| `dot-perf [-n N]` | speed report: GPU in use, effects, idle CPU, and how many ms each panel takes to open/close |
| `dot-restart-xcompose` | regenerate `~/.XCompose` |
| `dot-lock` | start hyprlock (once); uses a light, CPU-friendly lock screen in a VM or with `~/.config/hypr/low-effects` |
| `dot-sleep-log report` | what suspend costs: battery level before/after each suspend, %/h (recorded by hypridle) |
| `dot-check [--live]` | check shell scripts, Lua, JSON and QML for mistakes (`--live` = what is installed); `dot-reload shell` runs it first |

Tests: `python3 tests/test_qmlcheck.py` and `for t in tests/*.sh; do bash $t; done` (also run by CI).

Changes: `CHANGELOG.md`. Docs: `docs/KEYBINDINGS.md`, `docs/QUICKSHELL.md`, `docs/TROUBLESHOOTING.md`, `docs/APP-INTEGRATION.md`,
`docs/IMPROVEMENTS.md` (ideas and known gaps).
