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
./install.sh                    # copy configs (backs up anything overwritten)
./install.sh --dry-run          # preview only, changes nothing
./install.sh --with-deps        # also install the packages these depend on
./install.sh --with-deps --dry-run   # preview both, changes nothing
./install.sh --help
```

`--with-deps` is new as of Round 16 - see that section for exactly what it
installs and why each package name was chosen. It's Arch-specific (pacman +
an AUR helper); on anything else it just prints both package lists so you
can translate the names yourself.

The installer copies to `~/.config/`, backing up anything it overwrites to
`~/.config-backup-<timestamp>/`. If you'd rather do it by hand, just copy
`config/*` over `~/.config/` and `chmod +x` the shell scripts listed in
`install.sh`.

---
## Round 5: submap icons, colour cascade bug, and the wallpaper-colour pipeline

**Submap icons.** `SUPER+SHIFT+P` (power) and `SUPER+SHIFT+W` (wallpaper) now
show as icons in waybar's `#submap` indicator: `fa-power-off` (U+F011) and
`fa-picture-o` (U+F03E). Both verified directly against Font Awesome's own
reference pages ("Created: v1.0" on both) rather than typed from memory -
after the last icon mistake, I wasn't going to hand-type another invisible
character. They're also deliberately from Font Awesome's classic range
(0xF000-0xF2FF), which matters: **Nerd Fonts v3.0 did a breaking renumbering
of the newer Material Design icon set** (old 4-digit codepoints moved to new
5-digit ones). A few of your OWN original icons (network-disconnected, the
clock icon) already use the new 5-digit scheme, so they only render on a
recent Nerd Fonts build - if those specific two ever show as boxes while
everything else is fine, that's your font version, not this config.

**Found a real CSS bug while I was in there.** `#submap` was listed in two
separate rule blocks with equal specificity - one giving it `@urgent` (red)
text colour, a later one giving it `@dark-8` background. The later rule won
on background (source order), but the earlier rule's text colour was never
overridden, so you had grey background with alarm-red text, by accident,
matching neither block's intent. Split into one clean rule using `@highlight`
(your wallpaper's actual accent colour) per your ask to have it match the
wallpaper theme instead of looking like an error state.

**The colour pipeline "not matching/changing."** I checked every link in the
chain against primary documentation rather than guessing again:
- wpaperd's `exec` hook fires on every wallpaper change, confirmed via its
  own README, not just at startup.
- matugen's `config.toml` genuinely supports `~/...` paths - confirmed
  against matugen's own official wiki examples, which use exactly that.
- waybar's `SIGUSR2` defaults to a full `reload` - confirmed via the waybar
  man page.
- `reload_style_on_change` does cover `@import`-ed CSS files, not just the
  top-level file - confirmed via three independent copies of the man page.

All four check out correctly on paper. But one thing no config file can fix:
**`reload_style_on_change` is read once, at waybar's own startup.** If your
waybar process has been running since before this setting was added to
`config.jsonc`, that running process simply doesn't have it active - the
file being correct now doesn't retroactively change an already-running
process. Run `./debug-colors.sh` (new, at the repo root) - it traces every
step (is wpaperd running, did the hook log anything, did the CSS file's
mtime actually change, how long has your current waybar process been alive)
and tells you exactly which link is broken instead of me guessing a sixth
time.

---
## Round 6: the actual matugen crash, found via your own debug-colors.sh output

Running the diagnostic script surfaced a real, concrete error - exactly what
it was built for:

```
Error:
   0: Failed to read config file.
   1: TOML parse error at line 27, column 1
      [config.wallpaper]
      missing field `command`
```

`matugen/config.toml` had a `[config.wallpaper]` table with only
`set = false` in it. Per matugen's own current config wiki, that table's
`command` field has no real default - once the table exists at all, `command`
is required for the file to even parse, regardless of what `set` says.
`set = false` only controls whether the command gets *run*, not whether the
file needs to *have* one.

Worth being honest about: **this exact snippet was in your very first
upload**, before I ever touched the file. I carried it over in every round
without questioning it, and every TOML syntax check I ran along the way
passed - because it *is* syntactically valid TOML. It just doesn't satisfy
matugen's own schema on top of that, which a generic TOML parser has no way
of knowing. That's almost certainly why this specific error only showed up
now: it likely needed a matugen version update to start enforcing this
strictly, and every one of my "TOML OK" checks in earlier rounds was true but
insufficient.

Since the actual intent was always "matugen should never touch wallpaper
setting - wpaperd owns that," the fix is to remove the `[config.wallpaper]`
table entirely rather than fill in a placeholder command that would never
run. Confirmed against matugen's own wiki that wallpaper handling is
opt-in and simply doesn't exist if the table is never mentioned.

This should have been the actual, final missing piece: wpaperd's exec fires
correctly, matugen can now finish a whole run instead of dying on config
load, and waybar/kitty/etc. should pick up real colours the next time you
change wallpaper. If it still doesn't, run `debug-colors.sh` again - step 3
will now show either a clean matugen run or a new, different error, and
either result tells us something concrete.

---
## Round 7: colours work now, but the wallpaper icon vanishes on every change

Real interaction bug between two things that each looked fine on their own.

matugen's `[templates.waybar]` had `post_hook = 'pkill -USR2 -x waybar'`,
which I'd labelled "harmless" back when I added `reload_style_on_change`.
It wasn't harmless. Separately, `waybar/auto-reload.sh` watches
`~/.config/waybar` *recursively* for any file change - which includes
`waybar-colors.css`, the exact file matugen rewrites on every wallpaper
change. So one wallpaper change fired **two** `SIGUSR2`s: one from matugen's
own hook, one from the file watcher noticing the same write.

`SIGUSR2`'s default action is a full bar *reset*, not a style-only refresh
(confirmed via the waybar man page in an earlier round, but I didn't connect
it to this). `hyprland/submap` gets its displayed text from live Hyprland
IPC events - a full reset tears that module down and rebuilds it, and the
rebuilt instance has no memory of "we're still inside the wallpaper submap
right now." It only finds out on the *next* actual submap-change event. That's
exactly why the icon disappeared the instant a new wallpaper applied, even
though you hadn't pressed Escape.

Fixed both sides: removed matugen's `post_hook` entirely, and added an
explicit exclusion for `waybar-colors.css` in `auto-reload.sh`. Neither is
needed - `reload_style_on_change` (confirmed active, since your colours were
already updating live in the last test) already handles this file on its
own, gently, without touching any module's live state.

---
## Round 8: clock click opens a calendar instead of a browser

Was `"on-click": "firefox --app=https://calendar.google.com"` - a browser
window, not a calendar, and needs internet + a Google account to even show
anything. Replaced with `gsimplecal`: a small standalone GTK calendar popup
(50.7 KB installed, Arch **extra** repo, no AUR needed -
`sudo pacman -S gsimplecal`). Its own design is "click launches it, click
again closes it," which is exactly the interaction a panel-clock calendar
needs, with no wrapper script required.

Worth knowing: ML4W's actual clock-click calendar is a custom **AGS** widget
(AGS is a full GTK widget-shell framework, roughly comparable in scope to
`eww` - confirmed via their own CHANGELOG: *"AGS calendar widget moved from
sidebar into own widget. Opens with click on clock module in waybar"*).
Matching that exactly would mean adopting an entire separate widget-shell
framework and writing a widget in it, just for a calendar popup - a much
bigger dependency than anything else in this config touches. `gsimplecal`
gets the same "click the clock, a calendar appears" result without that.

Added `config/gsimplecal/config` with sane popup defaults: no window
decorations, marks today's date, and `close_on_unfocus = 1` so clicking
away dismisses it like a normal popup instead of needing a second click.
`mainwindow_yoffset` is a guess at sitting just under waybar - nudge it to
taste for your monitor and waybar's actual rendered height.

The hover tooltip (waybar's own built-in `{calendar}`) is untouched and
still works for a quick glance - this only changes what a full click does.

---
## Round 9: hovering or clicking the clock shows a different style

Real cause, and a general one: once a waybar module has an `on-click`
handler, waybar/GTK renders it as a clickable button - and GTK buttons carry
their OWN default hover/pressed styling from whatever system GTK theme is
installed, entirely separate from `waybar-colors.css`. Adding `on-click` to
the clock last round (for `gsimplecal`) made it a button for the first time,
and I'd never written a `#clock:hover`/`#clock:active` rule to override that
default chrome. So on hover and on click, the raw system theme's own button
colours briefly showed through instead of the custom look - which is exactly
"changes to a different style."

While in there, found a second, unrelated bug: `#clock` was listed in *two*
separate rules - the shared pills block gave it `background: @dark-8`, and a
later, separate rule overrode just the background to `transparent`. Same
cascade-conflict pattern as the `#submap` bug from Round 5. Consolidated into
one rule.

Since **every** clickable module has this same exposure, not just the clock,
added explicit `:hover`/`:active` resets to all of them - bluetooth, network,
cpu, memory, the volume slider group, and the media "now playing" piece -
rather than patching only the one you happened to notice.

Honesty about verification here: an ID selector plus `:hover` beats the
theme's generic `button:hover` by ordinary CSS specificity rules, and this is
the exact same mechanism `#workspaces button:hover` already uses successfully
elsewhere in this file - so the fix is on solid, well-established ground. I
tried to go further and verify the live GTK cascade directly (built a virtual
display in my sandbox and asked GTK itself to compute each state's colour),
but a bare test button doesn't faithfully reproduce waybar's actual internal
widget structure, and the results were inconclusive rather than confirming.
I'm not going to claim more certainty than I actually have - if this doesn't
fully resolve it, tell me exactly which module still shows the wrong colour
on hover/click and I'll dig into that one specifically.

---
## Round 10: calendar popup removed

`gsimplecal` reverted at your request - the clock's `on-click` is gone
entirely now, so clicking it does nothing. Removed `config/gsimplecal/config`
from the bundle too, and dropped `gsimplecal` from the dependencies list at
the bottom of this file.

The `#clock:hover`/`#clock:active` CSS rules from Round 9 only existed to
guard against GTK's default button chrome showing through on a *clickable*
clock. Without `on-click`, waybar won't render the clock as a button in the
first place, so those rules had nothing left to do - removed them as dead
weight rather than leaving inert CSS behind. The underlying bug fix from
Round 9 (the clock used to be listed in two separate rules fighting over its
background) is unrelated to the click behaviour and stays fixed either way.

The hover tooltip (waybar's own built-in `{calendar}`) was never touched by
any of this and still shows on mouseover, since you didn't ask to remove
that - only the click action.

---
## Round 11: volume slider never fully empties at 0%

`#pulseaudio-slider highlight` (the CSS node for the filled portion of the
volume bar) had `min-width: 10px` - a hard floor forcing that fill to render
at least 10px wide no matter what, including at 0% volume, where GTK would
otherwise correctly collapse it to nothing. The "0%" text next to it was
always accurate; the bar itself just physically couldn't reach empty because
of that floor. Removed it - `highlight` now has no minimum and can shrink to
zero width like `trough` (the fixed 75px background track) and `slider` (the
invisible drag handle, already correctly `min-width: 0`) were already doing
correctly.

---
## Round 12: mute/unmute icon

The mute icon glyph was already correct - `format-muted` has been set to
`fa-volume-off` (U+F026) since Round 4, and swaps in automatically whenever
you mute. What was missing was any colour change to go with it, so the swap
was easy to miss at a glance.

Added `#pulseaudio.muted { color: @urgent; }`. `.muted` is a real class
waybar applies on its own when the sink is muted - confirmed against the
waybar-pulseaudio man page's own STYLE section (`#pulseaudio`,
`#pulseaudio.bluetooth`, `#pulseaudio.muted` are listed as the module's
actual style hooks).

Verified this one properly, not just by reading the docs: built a real GTK
label in a virtual display, applied the `.muted` class, and read back what
GTK itself computed for the text colour. Unmuted came back as plain dark
text; with `.muted` applied, it resolved to `rgb(227, 81, 73)` - which is
`@urgent`'s exact defined value. The rule is confirmed to actually fire, not
just parse.

---
## Round 13: microphone mute/unmute icon

Added to the same `pulseaudio` module rather than a new one - it has native
built-in microphone/source support (`format-source`, `format-source-muted`,
and a `{format_source}` token that embeds whichever one currently applies),
confirmed against the waybar-pulseaudio man page's own FORMAT REPLACEMENTS
section, and against a real-world config using the exact same pattern.

Icons: `fa-microphone` (U+F130) / `fa-microphone-slash` (U+F131), both
verified directly against Font Awesome's own reference pages ("Created:
v3.1"), same stable classic range as everything else.

Caught a real mistake before shipping this: my first pass hardcoded the mic
icon directly into `format`/`format-muted` instead of embedding the literal
`{format_source}` token. That would have made the mic glyph just mirror
whichever *speaker*-mute branch was active, completely ignoring the mic's own
actual state - two independent things collapsed into one. Fixed by moving the
real glyphs into `format-source`/`format-source-muted` and embedding the
token in both branches instead. Verified this by simulating all four
independent speaker/mic combinations (on/on, on/muted, muted/on, muted/muted)
and confirming each renders the correct, independent pair of icons.

Also added `on-click-middle`: `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`,
so mic mute has a mouse-accessible toggle in the bar itself, not just the
`XF86AudioMicMute` hardware key from `hyprland.lua`.

One honest limit: the man page's STYLE section only documents `#pulseaudio`,
`#pulseaudio.bluetooth`, and `#pulseaudio.muted` as real CSS hooks - no
separate class for the source-muted sub-state is documented anywhere I could
find. So unlike the speaker mute (Round 12), this relies on the icon shape
alone, not a colour change. I didn't want to invent an unconfirmed class name
here, given where that kind of guess has gone before in this file.

---
## Round 14: mic icon was turning red when you muted the speaker

Real bug, confirmed with real Pango rendering, not just theory. The whole
`pulseaudio` module renders as ONE text label - both the speaker portion and
the mic portion (embedded via `{format_source}`) share it. `#pulseaudio.muted`
sets `color` for that entire label at once, so when you muted the speaker,
the ambient red applied to everything in the label, including the mic glyph
sitting right next to it - even when the mic itself wasn't muted at all.

Fixed with explicit inline `<span color=...>` markup around each mic glyph
individually. An inline span colour overrides the ambient label colour for
just that span, which decouples the mic's colour from the speaker's mute
state entirely.

Didn't just assume this works - parsed the actual combined markup through
real Pango for all four independent speaker/mic combinations (on/on, on/mute,
mute/on, mute/mute) and confirmed the exact colour, and exact byte range it
covers, for each one. Result: mic renders white when unmuted and
`rgb(227, 81, 73)` (`#e35149`, `@urgent`'s value) when muted, in every case,
completely independent of whatever the speaker is doing.

One real limitation, stated plainly: Pango spans need a literal colour value,
they can't reference a GTK CSS custom property like `@urgent`. So `#e35149`
and `#ffffff` are hardcoded to today's matugen defaults and won't update
automatically the next time your palette regenerates - same caveat that
already applied to the calendar's "today" highlight. If you want these two
to always match exactly, update them by hand after a big wallpaper/palette
change, or accept the small drift.

---
## Round 15: GTK theming, rofi dead-centre, and the real fix for the mic drift

### 1. GTK apps now themed via matugen too

Added `[templates.gtk3]` / `[templates.gtk4]` to `matugen/config.toml`, a new
`matugen/templates/gtk-colors.template`, and `config/gtk-3.0/gtk.css` /
`config/gtk-4.0/gtk.css` that import the generated colours. Content verified
against `InioX/matugen-themes` - the de-facto reference repo for this exact
integration (499 stars) - rather than guessed, since getting GTK's named
colour scheme wrong wouldn't crash anything, it would just silently theme
nothing, which is its own kind of hard-to-debug failure.

**This needs `adw-gtk3` installed and set as your active GTK3 theme** - GTK
theming only works because that theme's own CSS is written to reference
these overridable named colours (`@window_bg_color`, `@accent_color`, etc);
your *current* GTK3 theme almost certainly doesn't reference them at all, so
without switching to adw-gtk3 this template has nothing to override.

```bash
sudo pacman -S adw-gtk-theme
gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark   # or adw-gtk3
```

**Real limitation, not a bug**: GTK4/libadwaita apps read `gtk.css` once at
process start and have no live-reload signal - confirmed across every source
I found on this exact problem, including a PR that specifically set out to
solve it and still landed on "restart the app." New colours apply to newly
opened GTK4 apps immediately; already-running ones need closing and
reopening. GTK3 apps get a proper live reload via the `post_hook` (toggling
the theme off and back on, the standard documented trick).

**About Dolphin specifically**: it's a KDE/Qt app, not a GTK app - GTK
theming will not touch it, and I want to be upfront about that rather than
let it look covered when it isn't. Qt theming is a separate, heavier
mechanism (`qt5ct`/`qt6ct`, a compatible Qt style like Breeze or Darkly, and
several AUR packages), which I haven't added here since it's a meaningfully
bigger dependency footprint than the rest of this bundle. Say the word if you
want that added too - happy to do it properly rather than half-do it now.

### 2. Rofi: dead-centre instead of spotlight-anchored

Added to `rofi/config.rasi`'s existing "your own tweaks" section (the exact
extension point built for this back when the `@theme`/`?import` bug was
fixed):

```rasi
window {
    location: center;
    anchor: center;
    x-offset: 0px;
    y-offset: 0px;
}
```

`location` is the anchor point *on the monitor*, `anchor` is the anchor point
*on the window* - setting both to `center` aligns the window's own centre to
the screen's centre, true dead-centre rather than just vertically centred at
whatever x-offset spotlight-dark set. Width is untouched (still 32%),
per your ask.

Verification note: I installed real `rofi` in my sandbox and confirmed your
actual edited file loads with no "Failed to parse theme" error (checked
against a deliberately broken version first, to confirm my error-detection
was actually working and not just silent). I could not get `-dump-theme`'s
live output capture working in this headless sandbox to show the fully
resolved values directly - so this rests on confirmed-correct property
syntax (verified against rofi's own upstream source) plus a real,
error-free parse, not a full live render. If it doesn't land dead-centre
exactly, tell me what you're seeing.

### 3. The actual fix for the mic-colour drift

You were right to flag this - it's a real structural bug, not something
that "goes away" with a colour tweak. The old design embedded the mic
status inside the *same text label* as the speaker, coloured via a
hardcoded literal hex in a Pango `<span>` tag, because Pango spans can't
reference a GTK CSS variable like `@urgent`. Every time matugen regenerated
`@urgent` for a new wallpaper (including whatever wpaperd sets on boot),
the speaker's colour updated live and the mic's hardcoded value didn't -
so the two reds could drift apart, which is exactly "goes red to mild red."
I'd actually already flagged this exact risk as a caveat back in Round 14,
and it showed up in practice exactly as predicted.

Real fix, not a patch: pulled mic status into its own module entirely -
`custom/mic`, backed by a new script (`waybar/custom_modules/mic-status.sh`)
that queries `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` (output format
confirmed against three independent real-world implementations) and reports
a genuine `"class": "muted"` in its JSON payload. That gives it its own real
CSS node, which means a real CSS rule - `#custom-mic.muted { color: @urgent; }`
- can style it, using the actual live variable rather than a frozen copy.
Verified with real GTK cascade resolution: unmuted resolves to white
(`@text`), muted resolves to `rgb(227, 81, 73)` - `@urgent`'s exact live
value, not a hardcoded guess. Since this is genuine CSS, every future
matugen regeneration updates it automatically - the drift is structurally
impossible now, not just fixed for today's wallpaper.

The old `{format_source}`/Pango-span approach is fully removed from the
`pulseaudio` module, which is back to just showing speaker volume.

---
## Round 16: install.sh can now install dependencies too

New `--with-deps` flag. Every package name below was checked individually
against Arch's own package pages before going into either list - not carried
over from memory or an older guide, since a couple of common assumptions
about this exact stack turned out to be wrong:

**Official `extra` repo** (`pacman -S --needed`):
`hyprland hyprlock hypridle waybar wpaperd rofi-wayland kitty mako playerctl
jq inotify-tools grim slurp satty wl-clipboard cliphist brightnessctl
wireplumber adw-gtk-theme`

**AUR-only** (no official package exists): `matugen`, `zscroll`

Two corrections worth knowing about even if you already have things
installed:

- **`rofi` alone doesn't have working Wayland/layer-shell support on this
  stack.** The fork that actually implements it, `rofi-wayland`, is what's
  in the official repo - it `provides`/`conflicts` with plain `rofi`, so
  they're mutually exclusive. Installing plain `rofi` here would have
  silently given you a launcher that doesn't display correctly under
  Hyprland. If your rofi launcher has been working fine, you almost
  certainly already have `rofi-wayland`, not `rofi` - `pacman -Qi rofi` vs
  `pacman -Qi rofi-wayland` will tell you which.
- **`wpaperd`, `satty`, `cliphist`, and `adw-gtk-theme` are all official
  packages now**, not AUR, despite some older guides listing them there -
  they were AUR contributions that got promoted to `extra` at various
  points. Worth knowing so you don't end up on an AUR helper unnecessarily.

The script detects `pacman`; if it's absent (you're not on Arch), it prints
both lists instead of guessing at your distro's package manager - I can't
verify names for other distros the same way I verified these. It also
detects `yay` or `paru` for the AUR half; without either, it prints the
exact command to run once you have one, rather than trying to install an
AUR helper on your behalf (that felt like a bigger, riskier step to take
without asking than installing a couple of named packages).

Tested the actual logic, not just read it: mocked `pacman`, `yay`, and
`sudo` and confirmed the real command lines it builds, both with and
without an AUR helper present, plus confirmed `--dry-run` and the plain
config-copy path behave exactly as before - this is additive, nothing about
the existing install flow changed.

---
## Round 17: install.sh was silently undoing matugen every time you re-ran it

This is the real bug behind your two screenshots. At 08:21, right after a
reboot, waybar's mute icon showed `#ffb4ab` - I confirmed this by extracting
exact pixel colours from your actual screenshots (not eyeballing them): a
real, wallpaper-derived matugen colour. At 08:24, three minutes later, the
same icon showed `#e35149` - and that hex is not a coincidence or a new
wallpaper's colour, it's byte-for-byte the hardcoded placeholder value I
shipped in `config/waybar/waybar-colors.css` back in Round 4.

The cause: **`install.sh` was treating matugen's own generated output files
exactly like static config.** `waybar-colors.css`, `colors-matugen.conf`
(kitty), `colors-matugen` (ghostty), `mako-colors`, `colors-matugen.rasi`
(rofi), `colors-matugen.lua` (hyprland), and the two new GTK `colors.css`
files are all *outputs* - matugen rewrites them on every wallpaper change.
The copies in this bundle's `config/` folder are bootstrap placeholders,
there only so nothing references a missing file before matugen has ever run.
But every previous version of the installer compared them like anything
else: "different from the shipped copy -> back it up and overwrite it." A
live, correctly-generated file is *supposed* to differ from the static
placeholder - that's the entire point - so any re-run of `install.sh` (for
whatever reason - trying `--with-deps`, re-checking something, anything)
was quietly stomping real, working colours back to hardcoded 2026-era
defaults, every single time.

Fixed properly: `install.sh` now has an explicit `GENERATED_FILES` list.
Once one of those 8 files already exists at your destination, it's left
completely alone - no comparison, no backup, no overwrite - regardless of
how many times you run the installer. The placeholder only ever gets
installed on a genuine first-time setup, when the destination file doesn't
exist yet at all.

Also shipped two placeholders that were missing entirely:
`config/gtk-3.0/colors.css` and `config/gtk-4.0/colors.css` (added in Round
15 for GTK theming, but I never gave them a bootstrap default) - `gtk.css`'s
`@import 'colors.css'` had nothing to import before matugen's first run.

Tested by reproducing your exact bug end-to-end: fresh install, hand-set the
live file to a matugen-style colour different from the placeholder, re-ran
`install.sh`, confirmed the live colour survives. Also confirmed normal
config files (tested with `hyprland.lua`) still get the proper backup-and-
replace treatment - this fix is scoped to exactly those 8 files, nothing
else changed.

If you've already re-run the installer since this bug existed, your current
`~/.config/waybar/waybar-colors.css` (and the other 7) may still be stuck on
the placeholder defaults. Easiest fix: just change your wallpaper once
(`SUPER+SHIFT+W` then `l`) - matugen will regenerate all of them correctly,
and this fixed installer will never overwrite them again.

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
cliphist brightnessctl wireplumber adw-gtk-theme`, plus `zscroll` for the
scrolling title (the script degrades to unscrolled text without it) and the
`JetBrainsMono Nerd Font` / `Symbols Nerd Font` families.

GTK theming (Round 15) needs `adw-gtk-theme` installed and set as your
active GTK3 theme (`gsettings set org.gnome.desktop.interface gtk-theme
adw-gtk3-dark`) - without it, the generated colours have nothing to
override. Qt/KDE apps (Dolphin and similar) are not covered by this and
need a separate mechanism - see Round 15 for why.
