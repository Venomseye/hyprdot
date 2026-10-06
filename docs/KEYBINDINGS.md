# Keybindings

`Super` is the main modifier. There are **no submaps** any more (while one is
active every other key is swallowed, and nothing showed that it was on).

## Everyday

| Keys | Action |
| --- | --- |
| `Super+Space` | menu: apps and commands (Esc closes, Enter runs) |
| `Super+Return` | terminal |
| `Super+B` / `Super+E` | browser / file manager |
| `Super+Q` | close window |
| `Super+L` | lock (hyprlock) |
| `Super+Shift+P` | power menu: lock, suspend, log out, reboot, shut down (the last three ask for a second Enter) |
| `Super+N` | notification history (last ten) |
| `Super+Shift+N` | Do Not Disturb |
| `Super+Ctrl+W` / `Super+Ctrl+Shift+W` | next / previous wallpaper |
| `Print` | screenshot, full screen (saved + copied) |
| `Super+Ctrl+S` | screenshot a region and annotate it |

## Windows and workspaces

| Keys | Action |
| --- | --- |
| `Super+Arrows` | focus |
| `Super+Ctrl+Arrows` | move window |
| `Super+Shift+Arrows` | resize |
| `Super+F` / `Super+Shift+F` | maximise / fullscreen |
| `Super+Shift+T` | toggle floating |
| `Super+P` / `Super+J` / `Super+K` | pseudotile / toggle split / swap split (dwindle) |
| `Super+1..0` | go to workspace 1..10 |
| `Super+Shift+1..0` | move window to workspace |
| `Super+S` / `Super+Shift+S` | show scratchpad / send window to it |
| `Super+scroll` | next/previous workspace |
| `Super+drag` left / right button | move / resize window |

## Media and hardware keys

Volume, mute, mic mute, brightness and play/pause/next/previous keys work with the
usual `XF86` keys (also while locked).

## Compose key (text and emoji)

`Right Alt` is the Compose key: press and release it, then type a sequence, e.g.
`m a i l` for your email, `m s` for a smile. Sequences are in
`config/xcompose/XCompose.template`; values in `~/.config/xcompose/vars`.

* Doesn't work? `dot-restart-xcompose --check` says why (also under
  Menu -> Setup -> Check keyboard / Compose key).
* Use another key: `echo compose:rctrl > ~/.config/hypr/compose-key`, restart Hyprland.
  Options: `compose:ralt`, `compose:rctrl`, `compose:menu`, `compose:caps`, `compose:lwin`, `compose:prsc`.
* Apps read `~/.XCompose` when they start - reopen them after changing it.
* Always works, no setup: `Super+Space` -> Snippets / Emoji copies the text to the clipboard.
