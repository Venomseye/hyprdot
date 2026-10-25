#!/usr/bin/env bash
# End-to-end test of install.sh in a throw-away HOME:
#   fresh copy install, no-op re-run, updates vs. backups, migration from an old --link install,
#   removed files, and personal files that must never be touched.
#
#   bash tests/test_install.sh
#
# install.sh refuses to run as root, so when this runs as root (a container) it drops to `nobody`.
set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'chmod -R u+rwX "$T" 2>/dev/null; rm -rf "$T"' EXIT
pass=0; fail=0
check() { if eval "$2"; then echo "ok    $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }

as_user() {
    if [ "$(id -u)" = 0 ]; then
        command -v setpriv >/dev/null 2>&1 || { echo "need setpriv to drop root"; exit 1; }
        setpriv --reuid=65534 --regid=65534 --clear-groups "$@"
    else
        "$@"
    fi
}

# a private copy of the repo we are free to modify, and a fresh HOME
R="$T/repo"; mkdir -p "$R" "$T/home"
(cd "$repo" && tar --exclude='__pycache__' --exclude='.git' -cf - .) | (cd "$R" && tar -xf -)
chmod -R a+rX "$T"; chown -R 65534:65534 "$T" 2>/dev/null || chmod -R a+rwX "$T"

H="$T/home"
install() {   # install [args...]  -> output in $T/out, status in $RC
    ( cd "$R" && as_user env -i HOME="$H" PATH="/usr/bin:/bin:/usr/local/bin" XDG_CONFIG_HOME="$H/.config" \
        XDG_DATA_HOME="$H/.local/share" XDG_STATE_HOME="$H/.local/state" XDG_CACHE_HOME="$H/.cache" \
        timeout 180 bash "$R/install.sh" --yes --no-deps "$@" ) >"$T/out" 2>&1
    RC=$?
}
backups() { ls -d "$H"/.config-backup-* 2>/dev/null | wc -l; }
sumf() { sha1sum "$1" | cut -d' ' -f1; }

echo "--- 1. fresh copy install"
install
check "install.sh succeeded" '[ "$RC" = 0 ] || { tail -20 "$T/out"; false; }'
check "hyprland.lua is a REAL file, same content as the repo" '[ -f "$H/.config/hypr/hyprland.lua" ] && [ ! -L "$H/.config/hypr/hyprland.lua" ] && [ "$(sumf "$H/.config/hypr/hyprland.lua")" = "$(sumf "$R/config/hypr/hyprland.lua")" ]'
check "no symlink anywhere under ~/.config" '[ -z "$(find "$H/.config" -type l)" ]'
check "dot-reload is a real, executable file in ~/.local/bin" '[ -f "$H/.local/bin/dot-reload" ] && [ ! -L "$H/.local/bin/dot-reload" ] && [ -x "$H/.local/bin/dot-reload" ]'
check "hook scripts keep their executable bit" '[ -x "$H/.config/hooks/run-hooks" ] && [ -x "$H/.config/wpaperd/matugen-hook.sh" ]'
check "support files were installed (tools, VERSION, manifest)" '[ -f "$H/.local/share/hyprdot/tools/qmlcheck.py" ] && [ -f "$H/.local/share/hyprdot/VERSION" ] && [ -f "$H/.local/share/hyprdot/manifest" ]'
check "no backup directory was created (nothing to back up)" '[ "$(backups)" = 0 ]'

echo "--- 2. the install does not depend on the repo any more"
mv "$R" "$R.gone"
out="$(as_user env -i HOME="$H" PATH="$H/.local/bin:/usr/bin:/bin" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" dot-check --live --qml 2>&1)"; rc=$?
check "dot-check --live still works with the repo gone" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "0 error(s)"'
check "it really ran the copied qmlcheck.py (its summary line is there)" 'printf "%s" "$out" | grep -q "qml: [0-9]* file(s), 0 error(s)"'
mv "$R.gone" "$R"

echo "--- 3. re-running changes nothing"
install
check "second run: nothing copied" 'grep -q "copied: 0 " "$T/out"'
check "second run: no backup directory" '[ "$(backups)" = 0 ]'

echo "--- 4. updates: untouched files update silently, edited files are backed up"
echo "-- new repo version" >> "$R/config/hypr/rules.lua"                   # repo changed, you did not touch it
echo "-- my own edit" >> "$H/.config/hypr/bindings.lua"                    # you changed it...
echo "-- new repo version" >> "$R/config/hypr/bindings.lua"                # ...and the repo changed it too
install
check "untouched file was updated" 'tail -n 1 "$H/.config/hypr/rules.lua" | grep -q "new repo version"'
check "edited file was replaced by the repo version" 'tail -n 1 "$H/.config/hypr/bindings.lua" | grep -q "new repo version"'
check "...after your edited copy went to the backup" '[ "$(backups)" = 1 ] && grep -rq "my own edit" "$H"/.config-backup-*/hypr/bindings.lua'
check "...and only that one was backed up" '[ "$(find "$H"/.config-backup-* -type f | wc -l)" = 1 ]'

echo "--- 5. personal and generated files are never touched"
mkdir -p "$H/.config/xcompose" "$H/.config/wpaperd"
echo "name=me" > "$H/.config/xcompose/vars"; echo 'path = "/mine"' > "$H/.config/wpaperd/config.toml"
echo 'return { primary = "#123456" }' > "$H/.config/hypr/colors-matugen.lua"   # what matugen wrote
echo "-- bump" >> "$R/config/hypr/input.lua"
install
check "xcompose/vars untouched" 'grep -qx "name=me" "$H/.config/xcompose/vars"'
check "wpaperd/config.toml untouched" 'grep -q "/mine" "$H/.config/wpaperd/config.toml"'
check "live matugen colours not overwritten by the bootstrap file" 'grep -q "#123456" "$H/.config/hypr/colors-matugen.lua"'

echo "--- 6. a file removed from the repo: removed if untouched, kept if you edited it"
rm "$R/config/hypr/input.lua"; echo "x" > "$R/config/hypr/zzz-extra.lua"
install; echo "-- mine" >> "$H/.config/hypr/zzz-extra.lua"
rm "$R/config/hypr/zzz-extra.lua"
install
check "untouched file that left the repo was removed" '[ ! -e "$H/.config/hypr/input.lua" ]'
check "edited file that left the repo was kept" '[ -f "$H/.config/hypr/zzz-extra.lua" ] && grep -q mine "$H/.config/hypr/zzz-extra.lua"'
cp "$repo/config/hypr/input.lua" "$R/config/hypr/input.lua"

echo "--- 7. migrating from an old --link install"
rm -rf "$H/.config" "$H/.local" "$H"/.config-backup-*
install --link
check "link install made symlinks into the repo" '[ -L "$H/.local/bin/dot-reload" ] && [ -L "$H/.config/hypr/hyprland.lua" ]'
install
check "copy install replaced the links with real files" '[ -f "$H/.local/bin/dot-reload" ] && [ ! -L "$H/.local/bin/dot-reload" ] && [ -z "$(find "$H/.config" "$H/.local/bin" -type l)" ]'
check "the old links were backed up, not lost" '[ "$(backups)" -ge 1 ]'
mv "$R" "$R.gone"
check "nothing points at the repo now" '[ -z "$(find "$H/.config" "$H/.local/bin" -type l)" ] && [ -x "$H/.local/bin/dot-reload" ]'
mv "$R.gone" "$R"

echo; echo "$pass passed, $fail failed"; [ "$fail" = 0 ]
