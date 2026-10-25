#!/usr/bin/env bash
# Exercises dot-reload's safety net with a fake `quickshell` (no Wayland needed).
#   bash tests/test_dot_reload.sh
set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'pkill -u "$(id -u)" -x quickshell 2>/dev/null; rm -rf "$T"' EXIT
export HOME="$T" XDG_CONFIG_HOME="$T/cfg" XDG_CACHE_HOME="$T/cache" XDG_RUNTIME_DIR="$T/run" WAYLAND_DISPLAY=wayland-test
mkdir -p "$T/bin" "$T/cfg" "$T/cache" "$T/run"
cp -r "$repo/config/quickshell" "$T/cfg/quickshell"

# fake shell: loads unless the config it is pointed at contains a BROKEN file
cat > "$T/bin/quickshell" <<'FAKE'
#!/bin/bash
dir="$XDG_CONFIG_HOME/quickshell"
[ "${1:-}" = "-p" ] && dir="$2"
if [ -e "$dir/BROKEN" ]; then
    echo "ERROR: Type Tile unavailable"
    echo "ERROR: Failed to load configuration"
    exit 1
fi
echo "INFO: Launching config: \"$dir\""
# stay alive under the name "quickshell" (an `exec sleep` would rename the process)
echo "INFO: Configuration Loaded"
while true; do sleep 1; done
FAKE
chmod +x "$T/bin/quickshell"
export PATH="$T/bin:$PATH"

pass=0; fail=0
check() { if eval "$2"; then echo "ok    $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }
DR="$repo/bin/dot-reload"
# live (non-zombie) shells only: a container without a reaping PID 1 leaves defunct ones behind
live() { ps -u "$(id -u)" -o pid=,stat=,comm=,args= | awk '$2 !~ /^Z/ && $3 == "quickshell"'; }
count() { live | grep -c . || true; }
running_cfg() { live | head -n 1; }
live_pid() { live | awk '{print $1}' | head -n 1; }

echo "--- 1. healthy start saves a last-known-good copy"
"$DR" shell >/dev/null 2>&1
check "one shell running" '[ "$(count)" = 1 ]'
check "LKG copy exists" '[ -d "$T/cache/quickshell-lkg/theme" ]'

echo "--- 2. a QML error blocks the restart and leaves the working shell alone"
pid_before="$(live_pid)"
sed -i 's/radius: 10$/radius 10/' "$T/cfg/quickshell/quick/Tile.qml"
out="$("$DR" shell 2>&1)"; rc=$?
check "exit status 1" '[ "$rc" = 1 ]'
check "error names file and line" 'printf "%s" "$out" | grep -q "quick/Tile.qml:"'
check "same shell still running (pid unchanged)" '[ "$(live_pid)" = "$pid_before" ] && [ -n "$pid_before" ]'
check "told the user it was not restarted" 'printf "%s" "$out" | grep -q "not restarting"'

echo "--- 3. --force + a config that fails to load falls back to the last good copy"
touch "$T/cfg/quickshell/BROKEN"
out="$("$DR" shell --force 2>&1)"; rc=$?
check "reported failure (exit 1)" '[ "$rc" = 1 ]'
check "fell back: exactly one shell running" '[ "$(count)" = 1 ]'
check "...and it is the LKG copy" 'running_cfg | grep -q "quickshell-lkg"'
check "log mentions the fallback" 'printf "%s" "$out" | grep -qi "last known good"'

echo "--- 4. boot with a broken config starts the last good copy; boot when running is a no-op"
pkill -x quickshell; sleep 0.5
"$DR" boot >/dev/null 2>&1
check "boot started the LKG copy" 'running_cfg | grep -q "quickshell-lkg"'
out="$("$DR" boot 2>&1)"
check "boot while running does nothing" 'printf "%s" "$out" | grep -q "already running"; [ "$(count)" = 1 ]'

echo "--- 5. repaired config restarts normally and refreshes the copy"
rm "$T/cfg/quickshell/BROKEN"; sed -i 's/radius 10$/radius: 10/' "$T/cfg/quickshell/quick/Tile.qml"
"$DR" shell >/dev/null 2>&1; rc=$?
check "restart ok" '[ "$rc" = 0 ] && [ "$(count)" = 1 ]'
check "now running the live config (not the copy)" '! running_cfg | grep -q "quickshell-lkg"'

echo "--- 6. no last-known-good copy and a failing config"
pkill -x quickshell; sleep 0.5; rm -rf "$T/cache/quickshell-lkg"; touch "$T/cfg/quickshell/BROKEN"
out="$("$DR" boot 2>&1)"; rc=$?
check "fails cleanly (exit 1), nothing left running" '[ "$rc" = 1 ] && [ "$(count)" = 0 ]'
check "explains there is no copy" 'printf "%s" "$out" | grep -qi "no last-known-good"'

echo "--- 7. an oversized log is trimmed to its tail, not wiped"
pkill -x quickshell; sleep 0.5; rm -f "$T/cfg/quickshell/BROKEN"
python3 -c "print('old line\n' * 40000, end='')" > "$T/cache/quickshell.log"; echo "KEEP-THIS-LAST-LINE" >> "$T/cache/quickshell.log"
before="$(wc -c < "$T/cache/quickshell.log")"
"$DR" shell >/dev/null 2>&1
after="$(wc -c < "$T/cache/quickshell.log")"
check "log was over 256 KB before ($before bytes)" '[ "$before" -gt 262144 ]'
check "now much smaller ($after bytes)" '[ "$after" -lt 100000 ]'
check "the most recent old line survived the trim" 'grep -q KEEP-THIS-LAST-LINE "$T/cache/quickshell.log"'
check "new start is logged after it" 'tail -n 5 "$T/cache/quickshell.log" | grep -q "Configuration Loaded"'

echo; echo "$pass passed, $fail failed"; [ "$fail" = 0 ]
