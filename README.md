# Hyprland dotfiles — corrected (round 2)

## What changed since the last version I gave you

You reported a CSS crash and "keyboard not working properly." Here's exactly
what I found, and how I checked each thing this time — by running it against
the real parser, not just reading the spec and hoping.

**The CSS crash** (`style.css:145:7 Invalid name of pseudo-class`) — I had
added `#media:empty { ... }` to hide the media pill when nothing's playing.
`:empty` is a **web CSS** pseudo-class; it was never in GTK's implementation.
GTK's own pseudo-class list is `:hover :active :selected :disabled :checked
:indeterminate :backdrop :focus :focus-within :focus-visible :link :visited
:dir() :not() :nth-child()` and a few structural ones — no `:empty`. I
installed real GTK3 + PyGObject in my sandbox and ran your actual `style.css`
through `Gtk.CssProvider` (the same parser waybar itself uses) — it
reproduced your exact error message and location, then confirmed the fixed
file loads clean. The real fix needs no CSS trick at all: waybar has hidden
empty custom modules automatically since v0.6.7, so the background/padding
just needed to move off the shared group container onto the two children.

**"Keyboard not working properly"** — I can't run real Hyprland here to
reproduce this directly, so I went hunting for anything that could cause it,
and found a genuine, independently-confirmable bug: **your wallpaper submap
keybinds have probably never worked.** `wpaperctl`'s real subcommands are
`next-wallpaper` / `previous-wallpaper` / `toggle-pause-wallpaper` (confirmed
against `man wpaperctl`) — your original config called plain `next` /
`previous`, which aren't real subcommands. Fixed.

The other thing worth knowing: **you have a file at
`~/.config/hypr/hyprland.conf` that Hyprland's own comment says
`# This config is a STUB! This should never be generated.`** Hyprland writes
this file automatically as a fallback *only* when it can't find or load a
working `hyprland.lua`. If that's currently the active config — even
partially, even briefly in the past — your real binds (rofi on `SUPER+Space`,
terminal on `SUPER+Return`, workspace switching, resize, submaps, media
keys — all of it) don't exist, and only six bare-bones binds do
(`SUPER+Q`=open terminal, `SUPER+C`=kill, `SUPER+M`=shutdown menu,
`SUPER+E`=dolphin, `SUPER+V`=float, `SUPER+R`=menu). That would feel exactly
like "keyboard not working properly." See the troubleshooting section below —
this is the first thing to check.

I also re-verified every "helpful addition" I made last time against primary
sources, since the CSS mistake means I'd made at least one unverified claim.
Found and fixed two more:
- `matugen/config.toml` had three keys I invented (`prefer`, `caching`,
  `fallback_color`) that aren't in matugen's documented config schema. Removed
  them — only `source_color_index` is confirmed real (matugen's own
  changelog: *"add source_color_index to config"*).
- `mako/config`'s `on-button-middle` line had an unnecessary `-- ` separator
  not present in the documented example. Removed it to match `man mako(5)`
  exactly.
- I'd also told you `ghostty_config.ghostty` was "inert" and safe to delete.
  That was wrong — Ghostty actually loads both `config.ghostty` and `config`
  if present. Corrected the reasoning in `ghostty/config`'s comments (the
  practical outcome — shipping one file — doesn't change, since your two
  files were identical anyway).

## Round 3: the actual keyboard bug

You were stuck in the wallpaper **submap**. `SUPER+SHIFT+W` (bound in
`hyprland.lua`) switches Hyprland into a temporary mode where every keystroke
is reinterpreted as a submap command instead of being sent to whatever app
has focus - that's what a submap *is*, and it was working exactly as
designed. While you're in it: `l` = next wallpaper, `h` = previous wallpaper,
`space` = pause rotation. None of them type a character. That's also almost
certainly what mangled your earlier message to me - it had zero spaces in it
anywhere, which is exactly what you'd get if every space you typed silently
triggered "pause rotation" instead of a space character.

**Escape exits it** and was already correctly bound - that's the immediate
fix if it happens again.

The actual bug: this submap's own *name* was an invisible glyph (a Nerd Font
icon codepoint that renders as nothing outside a font that has it). waybar's
`#submap` module exists specifically to show you when a submap is active -
but with a blank name, it displayed literally nothing. So if a fat-finger, a
stuck modifier, or anything else ever put you in this mode, you'd have zero
visual sign why typing stopped working. Renamed it to plain text
(`"wallpaper"`) in both places it's referenced (`hl.dsp.submap(...)` and
`hl.define_submap(...)` have to match exactly, and now they do) - it's
unmissable in the bar from now on.

If this happens again with no `SUPER+SHIFT+W` press you remember making,
that points to a stuck or ghost-pressed Shift key - the `wev` check from
before will confirm that.

---
## Round 4: waybar icons went missing

Real bug, not a font problem on your end. Several icons in `config.jsonc`
(bluetooth, cpu, memory, network wifi/ethernet, volume mute/levels) are Nerd
Font glyphs from the Private Use Area - invisible in any plain-text view,
including the one I was editing in. When I rewrote `config.jsonc` from
scratch instead of carrying your original bytes over, I hand-typed several of
these blind and they came out empty or wrong. Every *normal* Unicode
character (the battery lightning bolt, the clock icon) survived fine, which
is the tell - it was specifically the invisible ones that broke.

Fixed by pulling the exact codepoints back out of your original upload
programmatically (`chr(0xf294)` etc., verified byte-for-byte against your
original file) rather than retyping anything. Confirmed via an actual JSON
parse that the decoded characters now match your original exactly, field by
field.

**This only fixes the file. You still need the font itself.** If icons show
as boxes/question marks/blank space after installing this, that's a font
problem, not a config problem:

```bash
fc-list | grep -i "nerd font"          # is it installed at all?
fc-match "Symbols Nerd Font"           # does that exact family name resolve?
```

If `fc-match` returns something other than a Nerd Font, install one (Arch:
`ttf-jetbrains-mono-nerd`; elsewhere: grab it from
github.com/ryanoasis/nerd-fonts) and restart waybar.



Everything lives under `config/`, mirroring `~/.config/`. Drop-in replacement
for the files you sent, plus a few new ones.

```
./install.sh            # backs up your current ~/.config, then copies these in
./install.sh --dry-run  # show what would happen and change nothing
```

The installer copies to `~/.config/`, backing up anything it overwrites to
`~/.config-backup-<timestamp>/`. If you'd rather do it by hand, just copy
`config/*` over `~/.config/` and `chmod +x` the four shell scripts.

---

## 1. The error you were hitting

```
Select the color you want to use as source color
> #da7546 …
Error:
   0: Failed to get source color.
   2: IO error: Input/output error (os error 5)
```

matugen 4.0 added an interactive source-colour picker that appears whenever an
image yields several good candidates. Your hook is run by wpaperd, which has no
usable terminal, so the picker's read fails with `EIO` and matugen aborts
*before writing any template*. Nothing wrong with the PNG.

Fixed in two places:

- `matugen/config.toml` sets `source_color_index = 0`, which makes matugen
  pick the most dominant colour and never prompt. (matugen 4.2 added this as a
  config key; before that it was CLI-only.)
- `wpaperd/matugen-hook.sh` also passes `--source-color-index 0` and redirects
  stdin from `/dev/null`, so it still works if the config ever goes missing.

---

## 2. Things that were broken

| # | What | Symptom | Fixed in |
|---|------|---------|----------|
| 1 | matugen interactive picker | no colours ever regenerate | `matugen/config.toml`, `wpaperd/matugen-hook.sh` |
| 2 | Two `@theme` lines in rofi | spotlight-dark silently discarded | `rofi/config.rasi` |
| 3 | No kitty reload hook | kitty keeps old palette until restart | `matugen/config.toml` |
| 4 | Missing hyprlock screencopy grant | black lock screen | `hypr/hyprland.lua` |
| 5 | `custom/media-time` never registered | elapsed/total never displayed | `waybar/config.jsonc` |
| 6 | playerctld treated as a real player | stale/duplicate track info | `get-active-player.sh` |
| 7 | Tab-separated fields parsed with `IFS=$'\t'` | empty field shifts everything left | all media scripts |
| 8 | `auto-reload.sh` non-recursive, one-shot | script edits never triggered a reload | `waybar/auto-reload.sh` |
| 9 | `include custom.conf` in kitty | error logged on every launch | `kitty/kitty.conf` |
| 10 | Cursor size 24 / 30 / 30 | XWayland cursor smaller than native | `hypr/hyprland.lua` |

### 2. rofi — why your theme wasn't applying

From `man 5 rofi-theme`, "Multiple file handling":

- `import` — import and parse a second file
- `theme` — **discard** theme, and load file as a fresh theme

You had two `@theme` lines. The second one threw spotlight-dark away and left
rofi running on nothing but four colour rules — no layout, no sizing. Now:

```rasi
@theme  "~/.local/share/rofi/themes/spotlight-dark.rasi"
?import "~/.config/rofi/colors-matugen.rasi"
```

`?import` (rather than `@import`) won't abort parsing if the file doesn't
exist yet. `~` is expanded by rofi, so the hardcoded `/home/lol` paths are gone.

### 3. kitty — the comment in your config was wrong

The old `matugen/config.toml` said kitty has `auto_reload_config` on by
default. kitty has no such option. A running kitty keeps its palette until it
receives SIGUSR1 or you press ctrl+shift+f5. There's a `post_hook` now.

### 4. hyprlock — the black lock screen

`hyprlock.conf` uses `path = screenshot`, which is a screencopy request. With
`ecosystem:enforce_permissions = true` and no grant, it's denied. Added:

```lua
hl.permission("/usr/(bin|local/bin)/hyprlock", "screencopy", "allow")
```

**Permission changes need a full Hyprland restart, not `hyprctl reload`.**

### 7. The separator bug (subtle, worth reading)

Tab is IFS whitespace in bash, so leading empty fields get eaten:

```bash
$ IFS=$'\t' read -r title artist <<< $'\tSome Artist'
title=[Some Artist]  artist=[]      # wrong — shifted left
```

A track with no title, or metadata with an empty artist, silently corrupted
every downstream field. All the media scripts now use `\x1f` (ASCII unit
separator), which isn't whitespace, so empty fields survive intact.

---

## 3. What got faster

`media-animation.sh` ran every 0.1s and called `get-active-player.sh`, which
ran `playerctl -l` plus one `playerctl status` per player. `media-now-playing-wrap.sh`
did the same plus three more `playerctl metadata` calls, every 0.3s. That's
roughly **30–40 processes per second, permanently**, to render a three-character
bar graph and a tooltip.

- `get-active-player.sh` caches for 700ms and writes the cache atomically
- the animation only re-checks status every 5th frame, and only prints when the
  output actually changes (no more 10 bar redraws/second)
- metadata comes back from one `--format` call instead of three separate ones

Rough result: **~2–3 processes/second instead of 30–40.**

`media-time.sh` deliberately still calls `playerctl position` separately — the
bare `position` command returns **seconds** while the `{{ position }}` format
variable returns **microseconds**, and conflating them is exactly the bug your
"do not divide" comment was guarding against.

---

## 4. New stuff

- **Border colours follow your wallpaper.** `matugen/templates/hyprland-colors.template`
  generates `hypr/colors-matugen.lua`; `hyprland.lua` loads it with
  `pcall(dofile, ...)`. A missing or malformed file falls back to the built-in
  palette instead of taking your session down. `dofile` not `require`, because
  `require` caches and `hyprctl reload` would keep serving stale colours.
- **Ghostty is themed too**, via `config-file = ?colors-matugen` at the bottom
  of the config (last-wins ordering). Opt out by deleting that line and
  `[templates.ghostty]`.
- **`~/.cache/current-wallpaper`** — a stable symlink the hook maintains on
  every wallpaper change. `hyprlock.conf` has a commented line to use it as the
  lock background, which needs no screencopy permission at all.
- **`SUPER + L` locks the screen.** You had no deliberate lock binding, only
  hypridle's 5-minute timeout. Also added `l` inside the `SUPER+SHIFT+P` power
  submap.
- **`reload_style_on_change: true`** in waybar's config — it watches imported
  CSS too, so matugen colour changes land without any external signal.
- `SUPER+SHIFT+F` for true fullscreen (you only had maximized on `SUPER+F`).
- `space` in the wallpaper submap toggles rotation pause.
- Screenshot bind sends a notification and no longer re-evaluates `$(date)`
  in two places.
- hypridle documents `ignore_dbus_inhibit` — this is what stops the screen
  locking mid-video.

---

## 5. Things I did not change, and why

- **`hypr/hyprland.conf`** is not in this bundle. It was Hyprland's autogenerated
  stub, and its binds conflicted with your Lua config (`SUPER+Q` was terminal
  there, close-window in Lua). Delete it: `rm ~/.config/hypr/hyprland.conf`.
- **`ghostty/config.ghostty`** was a byte-identical duplicate of `ghostty/config`.
  Ghostty only reads the latter. Delete it.
- **`waybar/config-minimal.jsonc` / `style-minimal.css`** are copied through
  untouched — they look like a reference/fallback set you keep around.
- **wpaperd `mode`** is left commented. Check `wpaperd --help` for the exact
  value names your build accepts before enabling it.

---

## 6. Worth considering: waybar's native `mpris` module

Your media stack is six shell scripts plus a zscroll dependency. waybar has a
built-in `mpris` module built on libplayerctl that defaults to
`player: playerctld` (always follows the active player) and supports
`ignored-players`, `format`, `format-[status]` and `{dynamic}`. It would replace
all of it with about ten lines of JSON and no polling at all.

You'd lose the scrolling marquee, which may well be the whole point for you, so
I've kept your version working rather than swapping it out. If you want to try:

```jsonc
"mpris": {
  "format": "{player_icon} {dynamic}",
  "format-paused": "{status_icon} <i>{dynamic}</i>",
  "player-icons": { "default": "▶", "spotify": "" },
  "status-icons": { "paused": "⏸" },
  "ignored-players": ["firefox"]
}
```

---

## 7. If your keybinds don't match this config (do this first)

```bash
# 1. Is Hyprland actually running your hyprland.lua, or the stub fallback?
#    If this prints keybinds you don't recognize (SUPER+R = menu, SUPER+V =
#    float, SUPER+C = kill), you're on the stub. Full restart required — see
#    step 3.
cat ~/.config/hypr/hyprland.conf 2>/dev/null | head -5

# 2. Look for the actual Lua error Hyprland hit. Config errors surface in the
#    rolling log and (briefly) as an on-screen banner:
hyprctl rollinglog | grep -iE "lua|error|config"
cat "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" 2>/dev/null | grep -iE "lua|error" | tail -30

# 3. Fixing hyprland.lua and running `hyprctl reload` is NOT enough to swap
#    back from the stub .conf to your real .lua — Hyprland only picks that
#    swap up on a full restart. Log out and back in (or from a TTY: kill
#    Hyprland and run `Hyprland` again). Then:
rm ~/.config/hypr/hyprland.conf   # delete the stub once your .lua is confirmed loading

# 4. Sanity-check for the single most common cause of "random" keyboard
#    behaviour in this Lua config format: two binds on the same key combo.
#    Hyprland registers both silently — no warning, no error — and which one
#    "wins" is undefined. (Confirmed via hyprwm/Hyprland discussion #14494.)
grep -oP 'hl\.bind\(\K[^,]+' ~/.config/hypr/hyprland.lua | sort | uniq -d
```

If `hyprctl rollinglog` shows a real Lua runtime error (not just the stub
warning), paste it back to me — that tells us exactly which `hl.*` call is
wrong, rather than me guessing.

## 8. Verify it worked

```bash
# 1. matugen runs headless — this is the actual regression test
matugen image ~/Pictures/Wallpapers/*.png </dev/null && echo "NO PROMPT — fixed"

# 2. the hook end-to-end
~/.config/wpaperd/matugen-hook.sh eDP-1 ~/Pictures/Wallpapers/yourfile.png
tail -20 ~/.cache/matugen-hook.log

# 3. rofi keeps its layout (should be spotlight-dark sized, not a bare list)
rofi -show drun

# 4. media scripts, by hand
~/.config/waybar/custom_modules/media/get-active-player.sh | cat -v   # expect  name^_Playing
~/.config/waybar/custom_modules/media/media-time.sh                   # expect  1:23/4:05

# 5. playerctld is excluded
playerctl --list-all            # will list playerctld
~/.config/waybar/custom_modules/media/get-active-player.sh   # must NOT say playerctld

# 6. process load (was 30-40, should be low single digits)
timeout 10 bash -c 'while :; do pgrep -c playerctl; sleep 1; done'
```

**After installing, restart Hyprland fully** — `hyprctl reload` will not apply
the new permission grants, so the lock screen stays black until you do.

## Dependencies

Required by these configs: `hyprland hyprlock hypridle waybar wpaperd matugen
rofi kitty mako playerctl jq inotify-tools grim slurp satty wl-clipboard
cliphist brightnessctl wireplumber`, plus `zscroll` for the scrolling title
(the script degrades to unscrolled text without it) and the
`JetBrainsMono Nerd Font` / `Symbols Nerd Font` families.
