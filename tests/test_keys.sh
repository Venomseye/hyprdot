#!/usr/bin/env bash
# dot-keys: reads the real bindings, finds duplicates, names things sensibly.
set -u
cd "$(dirname "$0")/.." || exit 1
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
command -v python3 >/dev/null || { echo "skip  python3 missing"; exit 0; }
out="$(bin/dot-keys config/hypr/bindings.lua)"
echo "$out" | grep -q '^Super+Q  *Close window' && ok "Super+Q is Close window" || bad "Super+Q line wrong"
echo "$out" | grep -q '^Super+Shift+1…0 ' && ok "workspace loop shown as 1…0" || bad "workspace loop missing"
echo "$out" | grep -q '^PrtSc  *Screenshot: this display' && ok "PrtSc -> Screenshot: this display" || bad "Print line wrong"
[ "$(echo "$out" | wc -l)" -ge 60 ] && ok "at least 60 binds listed" || bad "too few binds listed"
bin/dot-keys --check config/hypr/bindings.lua >/dev/null && ok "no duplicate keys in the real config" || bad "real config has duplicate keys"
t="$(mktemp)"; trap 'rm -f "$t"' EXIT
printf 'local mainMod = "SUPER"\nhl.bind(mainMod .. " + Q", hl.dsp.window.close())\nhl.bind("SHIFT + SUPER + Q", hl.dsp.window.close())\nhl.bind("SUPER + Q", hl.dsp.window.close())\n' >"$t"
bin/dot-keys --check "$t" >/dev/null && bad "duplicate not found" || ok "duplicate bind is reported (modifier order ignored)"
j="$(bin/dot-keys --json config/hypr/bindings.lua)"
echo "$j" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d)>30; assert all(set(x)=={"cat","keys","desc"} for x in d)' && ok "--json is valid tiles" || bad "--json invalid"
echo "$j" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert any(x["desc"]=="Focus window" and x["keys"][-1]=="\u2190\u2191\u2193\u2192" for x in d); assert not any(x["desc"] in ("Focus left","Move window left") for x in d)' && ok "arrow binds merge into one tile" || bad "arrows not merged"
echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
