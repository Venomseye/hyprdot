# hyprdot

Hyprland + Quickshell dotfiles with wallpaper-driven colours (matugen).

```bash
bash install.sh              # symlinks config/ -> ~/.config, bin/ -> ~/.local/bin
bash install.sh --with-deps  # ...and installs the programs the keybinds/menu launch (Arch)
bash install.sh --dry-run    # show what it would do, change nothing
```

`bash install.sh` also makes every script executable, so it works even if your
archive tool dropped the permission bits (use `hyprdot-main.tar.gz` to keep them).

On Arch it offers to install missing core packages (pacman, then an AUR helper -
building `yay` for you if you have none). Restart Hyprland afterwards.

| Tool | What it does |
| --- | --- |
| `dot-reload [hypr\|shell]` | reload Hyprland / restart Quickshell without stray processes |
| `dot-wallpaper next\|prev\|doctor\|init` | change wallpaper; fix "black wallpaper / nothing changes" |
| `dot-updates` | pending updates for the bar (Arch, Debian, Fedora, openSUSE, Void, Alpine) |
| `dot-power lock\|suspend\|logout\|reboot\|shutdown` | session actions with fallbacks (used by the menu and `Super+L`) |
| `dot-snippets` | text/emoji snippets for the menu (clipboard based) |
| `dot-doctor` | read-only diagnosis of black screen / no bar / keyboard / menu commands |
| `dot-restart-xcompose` | regenerate `~/.XCompose` |

Docs: `docs/KEYBINDINGS.md`, `docs/QUICKSHELL.md`, `docs/TROUBLESHOOTING.md`, `docs/APP-INTEGRATION.md`.
