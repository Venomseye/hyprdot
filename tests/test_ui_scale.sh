#!/usr/bin/env bash
# dot-ui-scale: validates the value, writes/removes the file.
set -u
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
run() { XDG_CONFIG_HOME="$d" PATH="/usr/bin:/bin" bin/dot-ui-scale "$@"; }
run 1.25 >/dev/null 2>&1; [ "$(cat "$d/hypr/ui-scale")" = 1.25 ] && ok "1.25 is stored" || bad "1.25 not stored"
run 3 >/dev/null 2>&1 && bad "3 accepted" || ok "3 is rejected"
run abc >/dev/null 2>&1 && bad "text accepted" || ok "text is rejected"
[ "$(cat "$d/hypr/ui-scale")" = 1.25 ] && ok "a rejected value leaves the old one" || bad "old value lost"
run reset >/dev/null 2>&1; [ ! -e "$d/hypr/ui-scale" ] && ok "reset removes the file" || bad "reset kept the file"
run | grep -q "1.0" && ok "default shows 1.0" || bad "default wrong"
echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
