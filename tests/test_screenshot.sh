#!/usr/bin/env bash
# dot-screenshot with stub grim/notify-send: saves the file and offers Open / Edit / Copy path.
set -u
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
mkdir -p "$d/bin" "$d/pics"
printf '#!/bin/sh\nfor a; do last="$a"; done\n[ "$last" = - ] && echo png || printf png > "$last"\n' >"$d/bin/grim"
printf '#!/bin/sh\nif [ "${1:-}" = "--help" ]; then echo "  -w, --wait"; echo "  -A, --action=[NAME=]TEXT"; exit 0; fi\necho "$@" >> "%s/notify.log"\necho open\n' "$d" >"$d/bin/notify-send"
printf '#!/bin/sh\necho "$@" > "%s/opened"\n' "$d" >"$d/bin/xdg-open"
chmod +x "$d"/bin/*
PATH="$d/bin:/usr/bin:/bin" XDG_PICTURES_DIR="$d/pics" bin/dot-screenshot all >/dev/null 2>&1
sleep 1
ls "$d"/pics/Screenshots/screenshot_*.png >/dev/null 2>&1 && ok "screenshot file written" || bad "no screenshot file"
grep -q -- '-A open=Open' "$d/notify.log" 2>/dev/null && grep -q 'Copy path' "$d/notify.log" && ok "notification offers Open / Edit / Copy path" || bad "no action buttons"
[ -s "$d/opened" ] && ok "pressing Open runs xdg-open on the file" || bad "Open did nothing"
echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
