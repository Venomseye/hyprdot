#!/usr/bin/env bash
# Tests (with fake wpaperd / wpaperctl / hyprlock / dbus-monitor, no Wayland needed) for:
#   * dot-wallpaper set / next / prev / rotate: no wpaperd restart when `wpaperctl` can do it,
#     and the restart fallback when it cannot
#   * dot-lock: the light lock config in a VM / with ~/.config/hypr/low-effects, the full one otherwise
#   * dot-check's guard that hyprlock.conf and hyprlock-low.conf do not drift
#   * the shell command BtState.qml runs for Bluetooth change events (quoting, exec, no orphans)
#
#   bash tests/test_wallpaper_lock_bt.sh
set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
cleanup() { pkill -u "$(id -u)" -f "$T/bin/" 2>/dev/null; pkill -x wpaperd 2>/dev/null; pkill -x hyprlock 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
pass=0; fail=0
check() { if eval "$2"; then echo "ok    $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }

export HOME="$T/home" XDG_CONFIG_HOME="$T/cfg" XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache" XDG_DATA_HOME="$T/share" WAYLAND_DISPLAY=wayland-test
mkdir -p "$T/bin" "$T/home/Pictures/Wallpapers" "$T/cfg/wpaperd" "$T/cfg/hypr" "$T/state"
WP="$T/home/Pictures/Wallpapers"; for n in a b c; do touch "$WP/$n.png"; done
export PATH="$T/bin:$PATH"

# ------------------------------------------------------------------ fakes
cat > "$T/bin/wpaperd" <<'EOF'
#!/bin/bash
echo $$ > "$FAKE_DIR/wpaperd.pid"
while true; do sleep 1; done
EOF
cat > "$T/bin/wpaperctl" <<'EOF'
#!/bin/sh
echo "$@" >> "$FAKE_DIR/ctl.log"
[ "$1" = set-wallpaper ] && [ -n "${FAIL_SET:-}" ] && exit 1
exit 0
EOF
chmod +x "$T/bin/wpaperd" "$T/bin/wpaperctl"; export FAKE_DIR="$T"
D="$repo/bin/dot-wallpaper"
cat > "$T/cfg/wpaperd/config.toml" <<EOF
[default]
path = "$WP"
duration = "30m"
sorting = "random"

[any]
path = "$WP"
EOF
cfgpath() { grep -m1 '^path' "$T/cfg/wpaperd/config.toml" | sed 's/^path = "//; s/"$//'; }
start_wpaperd() { setsid -f "$T/bin/wpaperd" >/dev/null 2>&1 </dev/null; sleep 0.4; }
wpid() { cat "$T/wpaperd.pid" 2>/dev/null; }

echo "--- wallpaper changes without restarting wpaperd"
start_wpaperd; p0="$(wpid)"; : > "$T/ctl.log"
bash "$D" set "$WP/b.png" >/dev/null 2>&1
check "set: config pinned to the image" '[ "$(cfgpath)" = "$WP/b.png" ]'
check "set: told wpaperd directly (set-wallpaper <image>)" 'grep -qx "set-wallpaper $WP/b.png" "$T/ctl.log"'
check "set: wpaperd was NOT restarted" '[ "$(wpid)" = "$p0" ] && kill -0 "$p0" 2>/dev/null'
bash "$D" next >/dev/null 2>&1; bash "$D" next >/dev/null 2>&1
check "next x2 while pinned: stepped b -> c -> a" '[ "$(cfgpath)" = "$WP/a.png" ]'
check "next x2: still the same wpaperd process" '[ "$(wpid)" = "$p0" ]'
: > "$T/ctl.log"; bash "$D" rotate >/dev/null 2>&1
check "rotate: config back to the folder" '[ "$(cfgpath)" = "$WP" ]'
check "rotate: resumed cycling with next-wallpaper" 'grep -qx "next-wallpaper" "$T/ctl.log"'
check "rotate: wpaperd was NOT restarted" '[ "$(wpid)" = "$p0" ]'

echo "--- fallback: restart when wpaperctl cannot do it"
FAIL_SET=1 bash "$D" set "$WP/c.png" >/dev/null 2>&1; sleep 0.8
check "set-wallpaper failed -> config still updated" '[ "$(cfgpath)" = "$WP/c.png" ]'
check "...and wpaperd was restarted (new process)" '[ -n "$(wpid)" ] && [ "$(wpid)" != "$p0" ]'
pkill -x wpaperd; sleep 0.4
bash "$D" rotate >/dev/null 2>&1; sleep 0.8
check "wpaperd not running -> it is started" 'pgrep -x wpaperd >/dev/null'
pkill -x wpaperd

echo "--- dot-lock"
cat > "$T/bin/hyprlock" <<'EOF'
#!/bin/bash
echo "$*" >> "$FAKE_DIR/lock.log"
while true; do sleep 1; done
EOF
chmod +x "$T/bin/hyprlock"
cp "$repo/config/hypr/hyprlock-low.conf" "$T/cfg/hypr/"
setvirt() { printf '#!/bin/sh\necho %s\n' "$1" > "$T/bin/systemd-detect-virt"; chmod +x "$T/bin/systemd-detect-virt"; }
lockrun() { : > "$T/lock.log"; pkill -x hyprlock 2>/dev/null; sleep 0.3; bash "$repo/bin/dot-lock" >/dev/null 2>&1 & sleep 0.6; LOCKARGS="$(cat "$T/lock.log")"; }
setvirt kvm;  lockrun; check "VM: the light config is used" 'printf "%s" "$LOCKARGS" | grep -q -- "-c $T/cfg/hypr/hyprlock-low.conf"'
setvirt none; lockrun; check "real hardware: the normal config" '[ -z "$LOCKARGS" ] || ! printf "%s" "$LOCKARGS" | grep -q hyprlock-low'
setvirt kvm;  touch "$T/cfg/hypr/full-effects"; lockrun; check "VM + full-effects marker: normal config" '! printf "%s" "$LOCKARGS" | grep -q hyprlock-low'
rm "$T/cfg/hypr/full-effects"
setvirt none; touch "$T/cfg/hypr/low-effects"; lockrun; check "real hardware + low-effects marker: light config" 'printf "%s" "$LOCKARGS" | grep -q hyprlock-low'
rm "$T/cfg/hypr/low-effects"
n1="$(wc -l < "$T/lock.log")"; bash "$repo/bin/dot-lock" >/dev/null 2>&1; sleep 0.3
check "already locked: a second lock is not started" '[ "$(wc -l < "$T/lock.log")" = "$n1" ]'
pkill -x hyprlock
# a hyprlock that rejects -c (older version, bad config): the screen must still lock
cat > "$T/bin/hyprlock" <<'LOCKEOF'
#!/bin/bash
echo "$*" >> "$FAKE_DIR/lock.log"
[ "${1:-}" = "-c" ] && exit 2
while true; do sleep 1; done
LOCKEOF
setvirt kvm; : > "$T/lock.log"; bash "$repo/bin/dot-lock" >/dev/null 2>&1 & sleep 1.5
check "light config rejected -> falls back to the normal lock screen" '[ "$(grep -c -- "^-c " "$T/lock.log")" = 1 ] && [ "$(grep -vc -- "^-c " "$T/lock.log")" -ge 1 ] && pgrep -x hyprlock >/dev/null'
pkill -x hyprlock; sleep 0.8
check "killing the lock screen on purpose does NOT start another one" '! pgrep -x hyprlock >/dev/null'

# a lock screen killed within seconds of starting must not be respawned either
cat > "$T/bin/hyprlock" <<'LOCKEOF'
#!/bin/bash
echo "$*" >> "$FAKE_DIR/lock.log"
while true; do sleep 1; done
LOCKEOF
: > "$T/lock.log"; bash "$repo/bin/dot-lock" >/dev/null 2>&1 & sleep 0.6
pkill -x hyprlock; sleep 1.2
check "light lock killed after <3 s is not respawned (only crashes/rejections fall back)" '! pgrep -x hyprlock >/dev/null && [ "$(wc -l < "$T/lock.log")" = 1 ]'

echo "--- hyprlock variants cannot drift"
mkdir -p "$T/chk"; cp -r "$repo/config" "$repo/tools" "$repo/bin" "$T/chk/" 2>/dev/null
out="$(bash "$T/chk/bin/dot-check" --lua 2>&1)"; rc=$?
check "in sync: dot-check passes" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "agree outside the background block"'
echo "-- someone edits only one file" >> "$T/chk/config/hypr/hyprlock.conf"
out="$(bash "$T/chk/bin/dot-check" --lua 2>&1)"; rc=$?
check "drift is caught (exit 1, says which files)" '[ "$rc" = 1 ] && printf "%s" "$out" | grep -q "hyprlock-low.conf has drifted"'

echo "--- Bluetooth event monitor command (from BtState.qml)"
cmd="$(python3 - "$repo/config/quickshell/services/BtState.qml" <<'PY'
import ast, re, sys
s = open(sys.argv[1]).read()
m = re.search(r'command: \["sh", "-c", (.*?)\]\n', s, re.S)
lits = re.findall(r'"(?:\\.|[^"\\])*"', m.group(1))
print("".join(ast.literal_eval(l) for l in lits))
PY
)"
check "extracted a shell command" '[ -n "$cmd" ]'
cat > "$T/bin/dbus-monitor" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$FAKE_DIR/dbus.args"
echo $$ > "$FAKE_DIR/dbus.pid"
while true; do echo "signal member=PropertiesChanged"; sleep 0.2; done
EOF
cat > "$T/bin/stdbuf" <<'EOF'
#!/bin/sh
shift            # drop -oL
exec "$@"
EOF
chmod +x "$T/bin/dbus-monitor" "$T/bin/stdbuf"
sh -c "$cmd" > "$T/dbus.out" 2>&1 &
shp=$!; sleep 0.8
check "it runs dbus-monitor on the SYSTEM bus" 'head -n 1 "$T/dbus.args" | grep -qx -- "--system"'
check "match rule 1 reaches dbus-monitor intact (quotes survived)" 'grep -qx "type='"'"'signal'"'"',sender='"'"'org.bluez'"'"',interface='"'"'org.freedesktop.DBus.Properties'"'"',member='"'"'PropertiesChanged'"'"',arg0='"'"'org.bluez.Device1'"'"'" "$T/dbus.args"'
check "match rule 2 (the adapter: powered on/off)" 'grep -q "arg0='"'"'org.bluez.Adapter1'"'"'" "$T/dbus.args"'
check "events arrive on stdout" '[ "$(grep -c PropertiesChanged "$T/dbus.out")" -ge 2 ]'
check "the shell BECAME dbus-monitor (exec): same pid" '[ "$(cat "$T/dbus.pid")" = "$shp" ]'
kill "$shp"; sleep 0.4
check "stopping it leaves no dbus-monitor behind" '! kill -0 "$(cat "$T/dbus.pid")" 2>/dev/null'
rm "$T/bin/stdbuf"
sh -c "$cmd" > "$T/dbus.out" 2>&1 & shp=$!; sleep 0.6
check "without stdbuf it still works" 'grep -q PropertiesChanged "$T/dbus.out"'
kill "$shp"; sleep 0.3
rm "$T/bin/dbus-monitor"
mkdir -p "$T/nobin"      # a PATH with no dbus-monitor at all (the sandbox may have a real one in /usr/bin)
env PATH="$T/nobin" /bin/sh -c "$cmd" >/dev/null 2>&1; rc=$?
check "without dbus-monitor it exits 3 (the poll keeps working)" '[ "$rc" = 3 ]'

echo "--- Bluetooth state command (from BtState.qml)"
bcmd="$(python3 - "$repo/config/quickshell/services/BtState.qml" <<'PY'
import ast, re, sys
s = open(sys.argv[1]).read()
m = re.search(r'id: poll\n\s+command: \["sh", "-c",(.*?)\]\n\s+stdout', s, re.S)
body = re.sub(r"//[^\n]*", "", m.group(1))           # drop QML comments between the string pieces
lits = re.findall(r'"(?:\\.|[^"\\])*"', body)
print("".join(ast.literal_eval(l) for l in lits))
PY
)"
check "extracted the poll command" '[ -n "$bcmd" ]'
btrun() { env PATH="$T/btbin:/usr/bin:/bin" /bin/sh -c "$bcmd" 2>&1; }
mkdir -p "$T/btbin"
printf '#!/bin/sh\ncase "$1" in show) echo "Powered: yes";; devices) if [ "$2" = Connected ]; then echo "Device AA:BB:CC:DD:EE:FF Headset"; else echo "Device AA:BB:CC:DD:EE:FF Headset"; echo "Device 11:22:33:44:55:66 Mouse"; fi;; esac\n' > "$T/btbin/bluetoothctl"; chmod +x "$T/btbin/bluetoothctl"
out="$(btrun)"
check "adapter present: power:yes, 1 connected, 2 known devices" 'printf "%s" "$out" | grep -qx "power:yes" && [ "$(printf "%s" "$out" | grep -c "^conn:")" = 1 ] && [ "$(printf "%s" "$out" | grep -c "^dev:")" = 2 ]'
printf '#!/bin/sh\necho "No default controller available"\n' > "$T/btbin/bluetoothctl"
out="$(btrun)"; check "no controller: power:none (tile hidden, correctly)" 'printf "%s" "$out" | grep -qx "power:none"'
printf '#!/bin/sh\nsleep 30\n' > "$T/btbin/bluetoothctl"
t0=$(date +%s); out="$(btrun)"; t1=$(date +%s)
check "bluetoothctl hangs (bluetoothd not running): the command still FINISHES (<20 s) with power:none" '[ $((t1 - t0)) -lt 20 ] && printf "%s" "$out" | grep -qx "power:none"'
rm -f "$T/btbin/bluetoothctl"; out="$(btrun)"
check "bluetoothctl not installed: reports missing" '[ "$out" = missing ]'

echo; echo "$pass passed, $fail failed"; [ "$fail" = 0 ]
