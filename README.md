# hyprdot

Hyprland + Quickshell dotfiles with wallpaper-driven colours (matugen).

```bash
bash install.sh              # COPIES config/ -> ~/.config and bin/ -> ~/.local/bin (backs up what you changed)
bash install.sh --with-deps  # ...and installs the programs the keybinds/menu launch (Arch)
bash install.sh --dry-run    # show what it would do, change nothing
bash install.sh --link       # symlink instead of copying (for developing inside this folder)
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
| `dot-wallpaper next\|prev\|doctor\|init` | change wallpaper; fix "black wallpaper / nothing changes" |
| `dot-updates` | pending updates for the bar (Arch, Debian, Fedora, openSUSE, Void, Alpine) |
| `dot-power lock\|suspend\|logout\|reboot\|shutdown` | session actions with fallbacks (used by the menu and `Super+L`) |
| `dot-snippets` | text/emoji snippets for the menu (clipboard based) |
| `dot-clip` | clipboard history entries for the menu (cliphist) |
| `dot-screenshot screen\|all\|region\|window [--edit]` | screenshots: active display, everything, selection, window |
| `dot-theme init\|doctor` | make GTK and Qt apps follow dark mode and the wallpaper colours |
| `dot-doctor` | read-only diagnosis of black screen / no bar / keyboard / menu commands |
| `dot-restart-xcompose` | regenerate `~/.XCompose` |
| `dot-lock` | start hyprlock (once); uses a light, CPU-friendly lock screen in a VM or with `~/.config/hypr/low-effects` |
| `dot-sleep-log report` | what suspend costs: battery level before/after each suspend, %/h (recorded by hypridle) |
| `dot-check [--live]` | check shell scripts, Lua, JSON and QML for mistakes (`--live` = what is installed); `dot-reload shell` runs it first |

Tests: `python3 tests/test_qmlcheck.py`, `bash tests/test_dot_reload.sh`, `bash tests/test_sleep_and_theme.sh`, `bash tests/test_install.sh`, `bash tests/test_wallpaper_lock_bt.sh` (also run by CI, `.github/workflows/check.yml`).

Docs: `docs/KEYBINDINGS.md`, `docs/QUICKSHELL.md`, `docs/TROUBLESHOOTING.md`, `docs/APP-INTEGRATION.md`,
`docs/IMPROVEMENTS.md` (ideas and known gaps).
