#!/usr/bin/env bash
#
# Deploy this repo's dotfiles by symlinking them into ~/.config.
#
#   ./install.sh                 deploy
#   ./install.sh --dry-run       print everything it would do, change nothing
#   ./install.sh --with-deps     also install the extra programs the keybinds and menu launch
#   ./install.sh --yes           answer yes to every prompt (install missing packages, carry on)
#   ./install.sh --no-deps       never offer to install packages
#   ./install.sh --help          this message
#
# Not executable after unpacking an archive? Run it as:  bash install.sh
# (it makes itself and every script in the repo executable)
#
# Order of operations:
#   1. Pre-flight   alert if hyprland, quickshell, matugen, wpaperd or qt6-wayland is missing;
#                   on Arch it offers to install them (pacman, and an AUR helper for the rest -
#                   building yay for you if you have none).
#   2. chmod +x     bin/*, config/hooks/*.d/*, run-hooks, and every config/**/*.sh.
#   3. Symlinks     config/<app>  ->  ~/.config/<app>
#                   bin/<script>  ->  ~/.local/bin/<script>
#   4. Backup       anything that would be replaced is MOVED (never deleted) into
#                   ~/.config-backup-YYYYMMDD_HHMMSS/ first. That directory is only
#                   created if something actually needs backing up.
#
# Links vs real directories. Most app directories are linked whole. Directories
# that matugen writes generated colour files into (hypr, quickshell, kitty,
# ghostty, gtk-3.0, gtk-4.0) and ones that hold personal data (xcompose/vars)
# are instead made REAL directories with each file linked individually. Otherwise
# every wallpaper change would rewrite files inside this git checkout.
# Generated files themselves are never linked: they are seeded once from the
# bootstrap copy in config/ and then left alone, so re-running this script
# can't stomp live wallpaper colours.
#
# The links point into this checkout - don't move or delete it afterwards.
# Nothing is ever deleted except dangling links this script created earlier.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC="$ROOT/config"
BIN_SRC="$ROOT/bin"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DEST="${XDG_BIN_HOME:-$HOME/.local/bin}"
BACKUP="$DEST-backup-$(date +%Y%m%d_%H%M%S)"

DRY_RUN=false
WITH_DEPS=false
ASSUME_YES=false
NO_DEPS=false
PREFLIGHT_RETRY=false

for arg in "$@"; do
    case "$arg" in
        -n|--dry-run)   DRY_RUN=true ;;
        -d|--with-deps) WITH_DEPS=true ;;
        -y|--yes)       ASSUME_YES=true ;;
        --no-deps)      NO_DEPS=true ;;
        -h|--help)
            sed -n '2,/^[^#]/{/^#/s/^# \{0,1\}//p}' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "unknown option: $arg (see --help)" >&2
            exit 2
            ;;
    esac
done

say()  { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
err()  { printf 'error: %s\n' "$*" >&2; }

ERRORS=0
linked=0; already=0; seeded=0; kept=0; backed_up=0; pruned=0; chmodded=0
BACKUP_MADE=false

run() {
    if $DRY_RUN; then printf '  would: %s\n' "$*"; return 0; fi
    "$@" || { err "failed: $*"; ERRORS=$((ERRORS + 1)); return 1; }
}

# ---------------------------------------------------------------------------
# Sanity
# ---------------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
    err "don't run this as root - the links would point into root's home"
    exit 1
fi
[ -d "$SRC" ] || { err "can't find $SRC - run this from the repository root"; exit 1; }
if [ "$(readlink -f "$DEST")" = "$(readlink -f "$SRC")" ]; then
    err "$DEST already IS $SRC (whole ~/.config linked into the repo). Undo that link first."
    exit 1
fi

# ---------------------------------------------------------------------------
# What needs which treatment
# ---------------------------------------------------------------------------

# Files matugen overwrites on every wallpaper change. Seeded once, never linked.
GENERATED_FILES=(
    "quickshell/theme/Colors.qml"
    "hypr/colors-matugen.lua"
    "hypr/hyprlock-colors.conf"
    "kitty/colors-matugen.conf"
    "ghostty/colors-matugen"
    "gtk-3.0/colors.css"
    "gtk-4.0/colors.css"
)

# Directories that are real dirs with per-file links even though they hold no
# generated file: xcompose/vars is personal data and must stay out of the repo.
# xcompose/vars is personal; wpaperd/config.toml has absolute paths for this machine.
EXTRA_SPLIT_DIRS=(xcompose wpaperd)

is_generated() {
    local g
    for g in "${GENERATED_FILES[@]}"; do [ "$1" = "$g" ] && return 0; done
    return 1
}

is_split_dir() {
    local g
    for g in "${GENERATED_FILES[@]}"; do [ "${g%%/*}" = "$1" ] && return 0; done
    for g in "${EXTRA_SPLIT_DIRS[@]}"; do [ "$g" = "$1" ] && return 0; done
    return 1
}

# name | binaries that satisfy it | how to get it
CORE_CHECKS=(
    "hyprland|Hyprland hyprland|pacman -S hyprland"
    "quickshell|quickshell qs|yay -S quickshell   (paru works too)"
    "matugen|matugen|yay -S matugen   (AUR only)"
    "wpaperd|wpaperd|pacman -S wpaperd"
)

# Not required to install, but the configs call them. Missing ones are listed.
RECOMMENDED_BINS=(
    hyprlock hypridle hyprshutdown hyprsunset kitty playerctl brightnessctl wpctl
    grim slurp satty wl-copy cliphist notify-send gsettings
)

# Arch package names. CORE = the desktop can't start without it. EXTRA = programs the
# keybinds, menu and bar widgets launch. Every name is looked up when installing:
# already installed -> skipped, in the official repos -> pacman, otherwise -> the AUR
# helper. One renamed or unknown package therefore can't sink the rest (pacman -S
# refuses the WHOLE transaction if a single name is not found).
PKGS_CORE=(
    hyprland xdg-desktop-portal-hyprland hyprlock hypridle wpaperd
    quickshell matugen qt6-wayland qt6-declarative
    pipewire wireplumber upower brightnessctl playerctl libnotify
    grim slurp satty wl-clipboard cliphist jq
)
PKGS_EXTRA=(
    hyprsunset hyprshutdown kitty btop nautilus firefox pavucontrol blueman wev
    pacman-contrib adw-gtk-theme noto-fonts-emoji ttf-jetbrains-mono-nerd bibata-cursor-theme
)

NOCONFIRM=()
$ASSUME_YES && NOCONFIRM=(--noconfirm)
FAILED_PKGS=()
AUR_HELPER=""

# ask "question" -> 0 for yes. --yes answers yes; with no terminal the answer is no.
ask() {
    $ASSUME_YES && return 0
    [ -t 0 ] || return 1
    local reply=""
    read -r -p "$1 [Y/n] " reply
    case "$reply" in [nN]*) return 1 ;; *) return 0 ;; esac
}

find_aur_helper() {
    local h
    for h in yay paru; do
        if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; return 0; fi
    done
    return 1
}

ensure_aur_helper() {
    find_aur_helper && return 0
    say "No AUR helper (yay/paru) found, and some packages exist only in the AUR."
    ask "Build yay from the AUR now? (needs git, base-devel and a network)" || return 1
    sudo pacman -S --needed "${NOCONFIRM[@]}" git base-devel || return 1
    local tmp
    tmp="$(mktemp -d)" || return 1
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
       && ( cd "$tmp/yay-bin" && makepkg -si "${NOCONFIRM[@]}" ); then
        rm -rf "$tmp"
        find_aur_helper
        return
    fi
    rm -rf "$tmp"
    return 1
}

# install_packages <names...>; names that end up missing are added to FAILED_PKGS.
install_packages() {
    local p repo=() aur=()
    for p in "$@"; do
        if pacman -Qq "$p" >/dev/null 2>&1; then continue
        elif pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p")
        else aur+=("$p"); fi
    done
    if [ "${#repo[@]}" -eq 0 ] && [ "${#aur[@]}" -eq 0 ]; then
        say "packages:  everything is already installed"
        return 0
    fi

    if [ "${#repo[@]}" -gt 0 ]; then
        say "pacman:    ${repo[*]}"
        if $DRY_RUN; then
            say "  would: sudo pacman -S --needed ${repo[*]}"
        elif ! sudo pacman -S --needed "${NOCONFIRM[@]}" "${repo[@]}"; then
            warn "pacman refused the batch - retrying one package at a time"
            for p in "${repo[@]}"; do sudo pacman -S --needed "${NOCONFIRM[@]}" "$p" || true; done
        fi
    fi

    if [ "${#aur[@]}" -gt 0 ]; then
        say "AUR:       ${aur[*]}"
        if $DRY_RUN; then
            say "  would: install with an AUR helper (building yay first if you have none): ${aur[*]}"
        elif ensure_aur_helper; then
            if ! "$AUR_HELPER" -S --needed "${NOCONFIRM[@]}" "${aur[@]}"; then
                warn "$AUR_HELPER refused the batch - retrying one package at a time"
                for p in "${aur[@]}"; do "$AUR_HELPER" -S --needed "${NOCONFIRM[@]}" "$p" || true; done
            fi
        fi
    fi

    $DRY_RUN && return 0
    for p in "${repo[@]}" "${aur[@]}"; do
        pacman -Qq "$p" >/dev/null 2>&1 || FAILED_PKGS+=("$p")
    done
}

# install_dependencies core|full
install_dependencies() {
    say "=== Dependencies ==="
    if ! command -v pacman >/dev/null 2>&1; then
        say "pacman not found - these are Arch package names; translate them for your distro:"
        printf '  %s\n' "${PKGS_CORE[@]}" "${PKGS_EXTRA[@]}"
        say ""
        return
    fi

    local list=("${PKGS_CORE[@]}")
    [ "${1:-core}" = full ] && list+=("${PKGS_EXTRA[@]}")
    FAILED_PKGS=()
    install_packages "${list[@]}"

    if [ "${#FAILED_PKGS[@]}" -gt 0 ]; then
        warn "could not install: ${FAILED_PKGS[*]}"
        say "  They may have been renamed or need an AUR helper. Look them up with:  yay -Ss <name>"
    fi
    say ""
}

# ---------------------------------------------------------------------------
# 1. Pre-flight
# ---------------------------------------------------------------------------

preflight() {
    say "=== Pre-flight: core packages ==="
    local entry name bins hint bin path missing=()

    for entry in "${CORE_CHECKS[@]}"; do
        IFS='|' read -r name bins hint <<<"$entry"
        path=""
        for bin in $bins; do
            if path="$(command -v "$bin" 2>/dev/null)"; then break; fi
            path=""
        done
        if [ -n "$path" ]; then
            printf 'ok       %-11s %s\n' "$name" "$path"
        else
            printf 'MISSING  %-11s install: %s\n' "$name" "$hint"
            missing+=("$name")
        fi
    done

    # Quickshell is a Qt app: without the Qt Wayland platform plugin it silently
    # falls back to X11/KMS and draws nothing (no bar).
    local qtw=""
    if command -v pacman >/dev/null 2>&1 && pacman -Qq qt6-wayland >/dev/null 2>&1; then
        qtw="package qt6-wayland"
    else
        qtw="$(ls /usr/lib/qt6/plugins/platforms/libqwayland*.so /usr/lib64/qt6/plugins/platforms/libqwayland*.so 2>/dev/null | head -1)"
    fi
    if [ -n "$qtw" ]; then
        printf 'ok       %-11s %s\n' "qt6-wayland" "$qtw"
    else
        printf 'MISSING  %-11s install: pacman -S qt6-wayland   (Quickshell draws nothing without it)\n' "qt6-wayland"
        missing+=("qt6-wayland")
    fi

    local rec=()
    for bin in "${RECOMMENDED_BINS[@]}"; do
        command -v "$bin" >/dev/null 2>&1 || rec+=("$bin")
    done
    if [ "${#rec[@]}" -gt 0 ]; then
        say ""
        say "note: optional tools not found (the matching keybinds/hooks will say so): ${rec[*]}"
    fi
    say ""

    [ "${#missing[@]}" -gt 0 ] || return 0

    warn "missing core packages: ${missing[*]}"
    say "  The configs can still be linked, but the desktop won't work until these are installed."

    if $DRY_RUN; then
        say "  (dry run: reporting only)"
        say ""
        return 0
    fi

    # Arch: offer to install them right now, then check again once.
    if command -v pacman >/dev/null 2>&1 && ! $NO_DEPS && ! $PREFLIGHT_RETRY; then
        if ask "Install the missing packages now (pacman, plus the AUR for the rest)?"; then
            install_dependencies core
            PREFLIGHT_RETRY=true
            preflight
            return
        fi
    fi

    if $ASSUME_YES; then
        warn "continuing anyway (--yes)"
        say ""
        return 0
    fi
    if [ -t 0 ]; then
        local reply=""
        read -r -p "Continue anyway? [y/N] " reply
        case "$reply" in [yY]*) say ""; return 0 ;; esac
    fi
    err "stopping before anything was changed. Install the packages, or re-run with --yes."
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Permissions
# ---------------------------------------------------------------------------

# Everything that's executed: bin/*, hook scripts (config/hooks/*.d/*, and a
# literal config/hooks/.d/ if you ever use one), run-hooks, and any .sh.
exec_candidates() {
    {
        printf '%s\0' "$ROOT/install.sh"
        [ -d "$BIN_SRC" ] && find "$BIN_SRC" -type f ! -name '.*' ! -iname 'README*' -print0
        [ -d "$SRC/hooks" ] && find "$SRC/hooks" -type f ! -name '.*' ! -iname 'README*' \
            \( -path '*.d/*' -o -name run-hooks \) -print0
        find "$SRC" -type f -name '*.sh' -print0
    } | sort -zu
}

make_executable() {
    say "=== Permissions ==="
    local f
    while IFS= read -r -d '' f; do
        [ -x "$f" ] && continue
        say "chmod +x   ${f#"$ROOT"/}"
        run chmod +x -- "$f" && chmodded=$((chmodded + 1))
    done < <(exec_candidates)
    [ "$chmodded" -eq 0 ] && say "all scripts already executable"
    say ""
}

# ---------------------------------------------------------------------------
# 3/4. Backup + symlinks
# ---------------------------------------------------------------------------

# backup_item <existing path> <path relative to the backup dir>
backup_item() {
    local path="$1" rel="$2"
    if ! $BACKUP_MADE; then
        run mkdir -p "$BACKUP" || return 1
        BACKUP_MADE=true
    fi
    run mkdir -p "$(dirname "$BACKUP/$rel")" || return 1
    run mv -- "$path" "$BACKUP/$rel" && backed_up=$((backed_up + 1))
}

# Files that exist in an old real directory but not in the repo: after the
# directory is swapped for a link they'd silently vanish from view.
note_orphans() {
    local old="$1" new="$2" f rel n=0
    while IFS= read -r -d '' f; do
        rel="${f#"$old"/}"
        [ -e "$new/$rel" ] && continue
        n=$((n + 1))
        [ "$n" -le 5 ] && say "           only in your old copy (kept in the backup): $rel"
    done < <(find "$old" -type f -print0 2>/dev/null)
    [ "$n" -gt 5 ] && say "           ... and $((n - 5)) more"
    return 0
}

# link_item <source> <target> <label> <backup-relative path>
link_item() {
    local src="$1" target="$2" label="$3" brel="$4" parent real_parent

    parent="$(dirname "$target")"
    if [ -d "$parent" ]; then
        real_parent="$(cd "$parent" && pwd -P)"
        case "$real_parent/" in
            "$ROOT"/*)
                warn "skipping $label: $parent is itself a link into the repo"
                return 1
                ;;
        esac
    fi

    if [ -L "$target" ]; then
        if [ "$(readlink -f "$target")" = "$(readlink -f "$src")" ]; then
            say "ok         $label"
            already=$((already + 1))
            return 0
        fi
        say "relink     $label   (old link -> backup)"
        backup_item "$target" "$brel" || return 1
    elif [ -e "$target" ]; then
        say "replace    $label   (old copy -> backup)"
        [ -d "$target" ] && [ -d "$src" ] && note_orphans "$target" "$src"
        backup_item "$target" "$brel" || return 1
    else
        say "link       $label"
    fi

    run mkdir -p "$parent" || return 1
    run ln -s -- "$src" "$target" && linked=$((linked + 1))
}

# A live generated file that was written by an old template this repo has since
# fixed. Left alone it would keep breaking the app, so it is backed up and
# reseeded (the placeholder is replaced by real colours again at the next
# wallpaper change - or at login, by hooks/.d/post-boot.d/01-startup.sh).
is_stale_generated() {
    case "$1" in
        # QML rejects properties called onPrimary/onSurface/... ("Cannot assign
        # a value to a signal"); they are primaryOn/surfaceOn/... now.
        quickshell/theme/Colors.qml) grep -qE 'property +color +on[A-Z]' "$2" 2>/dev/null ;;
        *) return 1 ;;
    esac
}

# Generated files are seeded once, then never touched.
seed_generated() {
    local src="$1" target="$2" label="$3" tmp resolved

    if [ -L "$target" ]; then
        resolved="$(readlink -f "$target")"
        if [ ! -e "$target" ]; then
            say "unlink     $label   (dangling link)"
            run rm -- "$target" || return 1
        elif [[ "$resolved" == "$ROOT"/* ]]; then
            # An older install linked this into the repo, so matugen has been
            # writing into the checkout. Keep the live content, make it a real file.
            say "unlink     $label   (was a link into the repo; matugen output must be a real file)"
            if $DRY_RUN; then
                printf '  would: replace the link with a real copy of its contents
'
            else
                tmp="$(mktemp)" && cp -L -- "$target" "$tmp" && rm -- "$target" && mv -- "$tmp" "$target" \
                    || { err "couldn't convert $label to a real file"; ERRORS=$((ERRORS + 1)); rm -f -- "${tmp:-}"; return 1; }
            fi
            seeded=$((seeded + 1))
            return 0
        else
            say "live       $label   (link elsewhere - left alone)"
            kept=$((kept + 1))
            return 0
        fi
    elif [ -e "$target" ]; then
        if is_stale_generated "$label" "$target"; then
            say "reseed     $label   (old copy has property names QML rejects; old one -> backup)"
            backup_item "$target" "$label" || return 1
        else
            say "live       $label   (matugen output - left alone)"
            kept=$((kept + 1))
            return 0
        fi
    fi

    say "seed       $label   (bootstrap placeholder)"
    run mkdir -p "$(dirname "$target")" || return 1
    run cp -- "$src" "$target" && seeded=$((seeded + 1))
}

# Dangling links that point into this repo = files that were removed from it.
prune_dangling() {
    local dir="$1" link
    [ -d "$dir" ] || return 0
    while IFS= read -r -d '' link; do
        case "$(readlink -- "$link")" in
            "$ROOT"/*)
                say "prune      ${link#"$HOME"/}   (no longer in the repo)"
                run rm -- "$link" && pruned=$((pruned + 1))
                ;;
        esac
    done < <(find "$dir" -xtype l -print0 2>/dev/null)
}

install_split_dir() {
    local app="$1" file rel

    if [ -L "$DEST/$app" ]; then
        say "unlink     $app/   (whole-directory link; this dir must be real - see header)"
        backup_item "$DEST/$app" "$app"
    fi

    while IFS= read -r -d '' file; do
        rel="${file#"$SRC"/}"
        if is_generated "$rel"; then
            seed_generated "$file" "$DEST/$rel" "$rel"
        else
            link_item "$file" "$DEST/$rel" "$rel" "$rel"
        fi
    done < <(find "$SRC/$app" -type f -print0 | sort -z)

    prune_dangling "$DEST/$app"
}

# True if the real directory $1 holds a file that doesn't exist in the repo's $2.
# Swapping such a directory for a link would hide that file from its app
# (e.g. your own wpaperd/config.toml), so those get per-file links instead.
has_orphans() {
    local old="$1" new="$2" f
    while IFS= read -r -d '' f; do
        [ -e "$new/${f#"$old"/}" ] || return 0
    done < <(find "$old" -type f -print0 2>/dev/null)
    return 1
}

install_config() {
    say "=== Config: $SRC -> $DEST ==="
    run mkdir -p "$DEST" || return 1

    local entry app
    while IFS= read -r -d '' entry; do
        app="$(basename "$entry")"
        if [ -d "$entry" ] && is_split_dir "$app"; then
            install_split_dir "$app"
        elif [ -d "$entry" ] && [ -d "$DEST/$app" ] && [ ! -L "$DEST/$app" ] && has_orphans "$DEST/$app" "$entry"; then
            say "keep       $app/   (has files that aren't in the repo - linking file by file so they stay put)"
            install_split_dir "$app"
        else
            link_item "$entry" "$DEST/$app" "$app$([ -d "$entry" ] && echo /)" "$app"
        fi
    done < <(find "$SRC" -mindepth 1 -maxdepth 1 ! -name '.*' -print0 | sort -z)
    say ""
}

install_bin() {
    [ -d "$BIN_SRC" ] || return 0
    say "=== Helper scripts: $BIN_SRC -> $BIN_DEST ==="
    run mkdir -p "$BIN_DEST" || return 1

    local f name
    while IFS= read -r -d '' f; do
        name="$(basename "$f")"
        link_item "$f" "$BIN_DEST/$name" "bin/$name" ".local/bin/$name"
    done < <(find "$BIN_SRC" -maxdepth 1 -type f ! -name '.*' -print0 | sort -z)

    prune_dangling "$BIN_DEST"

    case ":$PATH:" in
        *":$BIN_DEST:"*) ;;
        *) warn "$BIN_DEST is not in your PATH - add it to your shell profile" ;;
    esac
    say ""
}

# ---------------------------------------------------------------------------
# Wallpapers: give wpaperd something to show and something to change to
# ---------------------------------------------------------------------------

install_wallpapers() {
    [ -f "$BIN_SRC/dot-wallpaper" ] || return 0
    say "=== Wallpapers ==="
    if $DRY_RUN; then
        say "would: dot-wallpaper init --no-restart  (adds the bundled wallpapers to ~/Pictures/Wallpapers"
        say "       if it has fewer than two, creates wpaperd/config.toml if missing, adds a missing exec = line)"
    else
        bash "$BIN_SRC/dot-wallpaper" init --no-restart || warn "dot-wallpaper init reported a problem (run: dot-wallpaper doctor)"
    fi
    say ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$DRY_RUN && say "=== DRY RUN - nothing will be changed ==="

$WITH_DEPS && install_dependencies full
preflight
make_executable
install_config
install_bin
install_wallpapers

# Leftovers from the old Waybar/Rofi/Mako setup. Reported, never touched.
stale=()
for s in hypr/hyprland.conf ghostty/config.ghostty waybar mako rofi; do
    [ -e "$DEST/$s" ] && stale+=("$DEST/$s")
done
if [ "${#stale[@]}" -gt 0 ]; then
    say "--- leftovers from the old setup (safe to remove once you're happy) ---"
    printf '  %s\n' "${stale[@]}"
    say ""
fi

say "linked: $linked   already linked: $already   seeded: $seeded   live files left alone: $kept"
say "backed up: $backed_up   pruned: $pruned   chmod +x: $chmodded   errors: $ERRORS"

if $BACKUP_MADE; then
    if $DRY_RUN; then
        say "backup would go to: $BACKUP"
    else
        say "originals are in:   $BACKUP   (nothing was deleted)"
    fi
fi

if ! $DRY_RUN && [ "$ERRORS" -eq 0 ]; then
    say ""
    say "Next:"
    say "  0. Black screen, no bar, or the wallpaper won't change? Run dot-doctor, then dot-wallpaper doctor."
    say "  1. Restart Hyprland (not a reload) so the screencopy permissions apply."
    say "  2. cp $DEST/xcompose/vars.example $DEST/xcompose/vars, edit it, run dot-restart-xcompose."
    say "  3. Colours switch from the placeholder palette at the first wallpaper change"
    say "     (the post-boot hook also regenerates them a few seconds after login)."
    say "  Later: dot-reload reloads Hyprland and restarts Quickshell."
fi

[ "$ERRORS" -eq 0 ]
