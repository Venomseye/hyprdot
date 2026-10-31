#!/usr/bin/env bash
# dot-thermal against fake hardware: a healthy laptop, every kind of misconfiguration it must catch,
# a VM, and `setup` (dry run and real run with stubbed sudo/pacman/systemctl).
#
#   bash tests/test_thermal.sh
#
# `setup` refuses to run as root, so when this runs as root (a container) it drops to `nobody`.
set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'chmod -R u+rwX "$T" 2>/dev/null; rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "ok    $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

as_user() {
    if [ "$(id -u)" = 0 ]; then
        command -v setpriv >/dev/null 2>&1 || { echo "need setpriv to drop root"; exit 1; }
        setpriv --reuid=65534 --regid=65534 --clear-groups "$@"
    else
        "$@"
    fi
}

# --- stubs for the system tools the script asks -----------------------------------------------
ST="$T/state"; BIN="$T/bin"; mkdir -p "$ST" "$BIN"
cat >"$BIN/systemctl" <<'EOF'
#!/bin/sh
ST="${DOT_TEST_STATE:?}"
case "$1" in
    list-unit-files) n="${2%.service}"; [ -e "$ST/installed-$n" ] && echo "$n.service enabled enabled"; exit 0 ;;
    is-active)  shift; [ "$1" = --quiet ] && shift; [ -e "$ST/active-$1" ]; exit $? ;;
    is-enabled) shift; [ "$1" = --quiet ] && shift; [ -e "$ST/enabled-$1" ]; exit $? ;;
    *) echo "systemctl $*" >>"$ST/calls"; exit 0 ;;
esac
EOF
cat >"$BIN/systemd-detect-virt" <<'EOF'
#!/bin/sh
cat "${DOT_TEST_STATE:?}/virt" 2>/dev/null || echo none
EOF
cat >"$BIN/powerprofilesctl" <<'EOF'
#!/bin/sh
[ "$1" = get ] && { cat "${DOT_TEST_STATE:?}/ppd-profile" 2>/dev/null || echo balanced; }
exit 0
EOF
# sudo: records the command; `tee` is really executed so the fan write can be verified
cat >"$BIN/sudo" <<'EOF'
#!/bin/sh
case "$1" in tee|rm) exec "$@" ;; esac
echo "sudo $*" >>"${DOT_TEST_STATE:?}/calls"
EOF
cat >"$BIN/pacman" <<'EOF'
#!/bin/sh
[ "$1" = -Qq ] && exit 1
exit 0
EOF
chmod +x "$BIN"/*
chmod -R a+rX "$T"; chown -R 65534:65534 "$T" 2>/dev/null || chmod -R a+rwX "$T"

# --- fake machine builders ----------------------------------------------------------------------
new_machine() {   # new_machine <name> [intel|amd] -> sets $S (sys root) and $CI (cpuinfo)
    M="$T/m-$1"; S="$M/sys"; CI="$M/cpuinfo"
    rm -rf "$M" "$ST"/*; mkdir -p "$M/proc" "$M/units" "$S/class/hwmon" "$S/class/dmi/id" "$S/class/power_supply/BAT0" "$S/devices/system/cpu/cpu0/cpufreq"
    case "${2:-intel}" in
        intel) printf 'vendor_id\t: GenuineIntel\nmodel name\t: Fake Intel CPU\n' >"$CI" ;;
        amd)   printf 'vendor_id\t: AuthenticAMD\nmodel name\t: Fake AMD CPU\n'   >"$CI" ;;
    esac
    echo "ACME" >"$S/class/dmi/id/sys_vendor"; echo "Laptop 1" >"$S/class/dmi/id/product_name"
    echo Battery >"$S/class/power_supply/BAT0/type"
    echo intel_pstate >"$S/devices/system/cpu/cpu0/cpufreq/scaling_driver"
    echo powersave    >"$S/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    : >"$ST/installed-power-profiles-daemon"; : >"$ST/active-power-profiles-daemon"; : >"$ST/enabled-power-profiles-daemon"
    if [ "${2:-intel}" = intel ]; then : >"$ST/installed-thermald"; : >"$ST/active-thermald"; : >"$ST/enabled-thermald"; fi
    hw "coretemp" 1 45000 2400          # a healthy CPU hwmon with one fan reading
}
hw() {  # hw <name> <idx> <temp_millideg> <rpm> [pwm_enable] [pwm]
    local d="$S/class/hwmon/hwmon$2"; mkdir -p "$d"
    echo "$1" >"$d/name"; echo "$3" >"$d/temp1_input"; echo "Package id 0" >"$d/temp1_label"
    [ -n "${4:-}" ] && echo "$4" >"$d/fan1_input"
    [ -n "${5:-}" ] && echo "$5" >"$d/pwm1_enable"
    [ -n "${6:-}" ] && echo "$6" >"$d/pwm1"
    chmod -R a+rX "$M"; chown -R 65534:65534 "$M" 2>/dev/null || chmod -R a+rwX "$M"
    return 0
}
fin() { chmod -R a+rwX "$M" "$ST" 2>/dev/null; chown -R 65534:65534 "$M" "$ST" 2>/dev/null; true; }

tool() {   # tool <args...> -> stdout in $OUT, status in $RC
    fin
    OUT="$(as_user env -i HOME="$T" PATH="$BIN:/usr/bin:/bin" DOT_TEST_STATE="$ST" DOT_SYS="$S" DOT_CPUINFO="$CI" \
        DOT_MODULES="$M/modules" DOT_PROC="$M/proc" DOT_UNIT_DIR="$M/units" DOT_THERMAL_NO_LOAD=1 bash "$repo/bin/dot-thermal" "$@" 2>&1)"
    RC=$?
}
problems() { tool --machine; printf '%s\n' "$OUT" | grep -c '^PROBLEM|' || true; }
mkgpu() {  # mkgpu <cardN> <vendor id> <boot_vga> <runtime_status>   (pci address derived from N)
    local n="${1#card}" pci; pci="0000:0$((n + 1)):00.0"
    mkdir -p "$M/pci/$pci/power" "$M/pci/$pci/drm/renderD$((128 + n))" "$S/class/drm/$1"
    ln -s "$M/pci/$pci" "$S/class/drm/$1/device"
    echo "$2" >"$M/pci/$pci/vendor"; echo "$3" >"$M/pci/$pci/boot_vga"
    echo "$4" >"$M/pci/$pci/power/runtime_status"; echo auto >"$M/pci/$pci/power/control"
}
mkconn() {  # mkconn <cardN> <connector> <connected|disconnected>
    mkdir -p "$S/class/drm/$1-$2"; echo "$3" >"$S/class/drm/$1-$2/status"
}
mkproc() {  # mkproc <pid> <comm> <dri node>
    mkdir -p "$M/proc/$1/fd"; echo "$2" >"$M/proc/$1/comm"; ln -s "/dev/dri/$3" "$M/proc/$1/fd/5"
}
mkbat() {   # mkbat <capacity> <status> <threshold|-> <mains online 0|1>
    local b="$S/class/power_supply/BAT0" ac="$S/class/power_supply/AC"
    mkdir -p "$ac"; echo "$1" >"$b/capacity"; echo "$2" >"$b/status"
    [ "$3" = - ] || echo "$3" >"$b/charge_control_end_threshold"
    echo Mains >"$ac/type"; echo "$4" >"$ac/online"
}
has_problem() { printf '%s\n' "$OUT" | grep -q "^PROBLEM|.*$1"; }

echo "--- 1. a healthy laptop"
new_machine healthy
tool --machine
check "no problems on a healthy Intel laptop"      '[ "$(printf "%s\n" "$OUT" | grep -c "^PROBLEM|")" -eq 0 ]'
tool status
check "status shows the temperature and the fan"   'printf "%s\n" "$OUT" | grep -q " 45 C" && printf "%s\n" "$OUT" | grep -q "2400 RPM"'
check "status exits 0"                             '[ "$RC" -eq 0 ]'
tool doctor
check "doctor says nothing tripped, exits 0"       '[ "$RC" -eq 0 ] && printf "%s\n" "$OUT" | grep -q "none of the automatic checks tripped"'

echo "--- 2. nothing manages power and heat"
new_machine nopolicy
rm -f "$ST"/*power-profiles-daemon "$ST"/*thermald
tool --machine
check "missing power-profiles-daemon is reported with the fix"  'has_problem "power-profiles-daemon is not installed"'
check "missing thermald is reported on Intel"                   'has_problem "thermald is not installed"'
tool doctor
check "doctor exits 1 and points at setup"                      '[ "$RC" -eq 1 ] && printf "%s\n" "$OUT" | grep -q "dot-thermal setup"'
new_machine amd amd
rm -f "$ST"/*thermald
tool --machine
check "thermald is NOT demanded on AMD"                         '! has_problem "thermald"'
new_machine tlp
rm -f "$ST"/*power-profiles-daemon; : >"$ST/active-tlp"; : >"$ST/installed-tlp"
tool --machine
check "tlp managing power is a valid alternative to ppd"        '! has_problem "power-profiles-daemon is not installed"'
new_machine fight
: >"$ST/active-tlp"; : >"$ST/installed-tlp"
tool --machine
check "tlp + power-profiles-daemon together are flagged"        'has_problem "both running"'
new_machine stopped
rm -f "$ST/active-power-profiles-daemon"
tool --machine
check "installed-but-stopped ppd is flagged"                    'has_problem "installed but not running"'

echo "--- 3. fans stuck in manual / full speed"
new_machine manual
hw "nct6775" 2 40000 1500 1 128
tool --machine
check "manual pwm with no controller is flagged"                'has_problem "MANUAL mode"'
: >"$ST/active-fancontrol"; : >"$ST/installed-fancontrol"
tool --machine
check "manual pwm is fine while fancontrol runs"                '! has_problem "MANUAL mode"'
new_machine fullspeed
hw "nct6775" 2 40000 3000 0 255
tool --machine
check "pwm_enable=0 (full speed) is flagged"                    'has_problem "full speed"'
new_machine auto
hw "nct6775" 2 40000 1500 5 120
tool --machine
check "automatic pwm (mode 5) is fine"                          '[ "$(printf "%s\n" "$OUT" | grep -c "^PROBLEM|")" -eq 0 ]'

echo "--- 4. hot but the fan reads 0"
new_machine deadfan
echo 82000 >"$S/class/hwmon/hwmon1/temp1_input"; echo 0 >"$S/class/hwmon/hwmon1/fan1_input"
tool --machine
check "82 C with 0 RPM is flagged"                              'has_problem "reads 0 RPM"'
new_machine coolstop
echo 40000 >"$S/class/hwmon/hwmon1/temp1_input"; echo 0 >"$S/class/hwmon/hwmon1/fan1_input"
tool --machine
check "0 RPM at 40 C (fan-stop) is NOT flagged"                 '! has_problem "reads 0 RPM"'

echo "--- 5. policy: platform profile, governor, throttling"
new_machine perf
mkdir -p "$S/firmware/acpi"; echo performance >"$S/firmware/acpi/platform_profile"; echo "low-power balanced performance" >"$S/firmware/acpi/platform_profile_choices"
tool --machine
check "platform profile 'performance' is flagged"               'has_problem "platform profile is .performance"'
new_machine gov
echo performance >"$S/devices/system/cpu/cpu0/cpufreq/scaling_governor"
tool --machine
check "governor pinned to performance is flagged"               'has_problem "governor is .performance"'
new_machine ppdperf
echo performance >"$S/devices/system/cpu/cpu0/cpufreq/scaling_governor"; echo performance >"$ST/ppd-profile"
tool --machine
check "ppd 'performance' is flagged as the choice, not as a stray governor"  'has_problem "set to .performance" && ! has_problem "governor is"'
new_machine throttle
mkdir -p "$S/devices/system/cpu/cpu0/thermal_throttle"; echo 12 >"$S/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count"; echo 0 >"$S/devices/system/cpu/cpu0/thermal_throttle/core_throttle_count"
tool --machine
check "thermal throttle events are flagged"                     'has_problem "throttled 12 times"'
new_machine nodrv
rm -rf "$S/devices/system/cpu/cpu0/cpufreq"
tool --machine
check "no cpufreq driver is flagged"                            'has_problem "no cpufreq driver"'

echo "--- 6. no sensors / no fan sensor"
new_machine nosensors
rm -rf "$S/class/hwmon/hwmon1"
tool --machine
check "no temperature sensors at all is flagged"                'has_problem "no temperature sensors"'
new_machine nofan
rm -f "$S/class/hwmon/hwmon1/fan1_input"
tool status
check "no fan sensor is explained, not an error"                'printf "%s\n" "$OUT" | grep -q "no fan speed sensor is exposed" && [ "$RC" -eq 0 ]'
tool --machine
check "no fan sensor alone is NOT a problem"                    '! has_problem "fan"'

echo "--- 7. a virtual machine has nothing to fix"
new_machine vm
echo kvm >"$ST/virt"; rm -f "$ST"/*power-profiles-daemon "$ST"/*thermald
tool --machine
check "VM: no problems reported"                                '[ "$(printf "%s\n" "$OUT" | grep -c "^PROBLEM|")" -eq 0 ]'
tool status
check "VM: says the fans belong to the host"                    'printf "%s\n" "$OUT" | grep -q "belong to the host"'

echo "--- 8. setup"
new_machine setup
rm -f "$ST"/*power-profiles-daemon "$ST"/*thermald
hw "nct6775" 2 40000 1500 1 128
tool setup --dry-run
check "dry run lists what it would do"                          'printf "%s\n" "$OUT" | grep -q "would: sudo pacman -S" && printf "%s\n" "$OUT" | grep -q "would: sudo systemctl enable --now power-profiles-daemon"'
check "dry run asks for thermald on Intel"                      'printf "%s\n" "$OUT" | grep -q "enable --now thermald"'
check "dry run changed nothing (no sudo call, pwm untouched)"   '[ ! -s "$ST/calls" ] && [ "$(cat "$S/class/hwmon/hwmon2/pwm1_enable")" = 1 ]'
check "dry run mentions the manual fan"                         'printf "%s\n" "$OUT" | grep -q "would: write 2"'
tool setup --yes
check "setup installs the missing packages"                     'grep -q "sudo pacman -S --needed --noconfirm power-profiles-daemon thermald lm_sensors" "$ST/calls"'
check "setup does not enable not-installed units (pacman is a stub)"  '! grep -q "enable --now" "$ST/calls"'
check "setup hands the manual fan back to automatic"            '[ "$(cat "$S/class/hwmon/hwmon2/pwm1_enable")" = 2 ]'
new_machine setup2
: >"$ST/installed-power-profiles-daemon"; : >"$ST/installed-thermald"; rm -f "$ST"/active-* "$ST"/enabled-*
tool setup --yes
check "installed-but-off services get enabled"                  'grep -q "sudo systemctl enable --now power-profiles-daemon" "$ST/calls" && grep -q "sudo systemctl enable --now thermald" "$ST/calls"'
new_machine setup3
: >"$ST/active-fancontrol"; : >"$ST/installed-fancontrol"
hw "nct6775" 2 40000 1500 1 128
tool setup --yes
check "setup leaves fans alone while fancontrol owns them"      '[ "$(cat "$S/class/hwmon/hwmon2/pwm1_enable")" = 1 ]'
new_machine setup4
rm -f "$ST"/*power-profiles-daemon; : >"$ST/active-tlp"; : >"$ST/installed-tlp"
tool setup --dry-run
check "setup does not add ppd next to tlp"                      '! printf "%s\n" "$OUT" | grep -q "enable --now power-profiles-daemon"'
tool setup --bogus
check "unknown option is rejected"                              '[ "$RC" -eq 2 ]'

echo "--- 9. graphics: discrete GPUs"
new_machine gpu1
mkgpu card0 0x1002 1 active
tool --machine
check "a single GPU is never a problem"                         '[ "$(printf "%s\n" "$OUT" | grep -c "^PROBLEM|")" -eq 0 ]'
new_machine gpu-hdmi
mkgpu card0 0x1002 1 active; mkgpu card1 0x1002 0 active; mkconn card1 HDMI-A-1 connected
tool --machine
check "dGPU awake because it drives HDMI is NOT a problem"      '[ "$(printf "%s\n" "$OUT" | grep -c "^PROBLEM|")" -eq 0 ]'
tool status
check "...and the output says why it is awake"                  'printf "%s\n" "$OUT" | grep -q "awake because it drives: HDMI-A-1"'
check "...and marks it as looking discrete"                     'printf "%s\n" "$OUT" | grep -q "looks discrete"'
new_machine gpu-idle
mkgpu card0 0x1002 1 active; mkgpu card1 0x1002 0 active; mkconn card1 HDMI-A-1 disconnected
mkproc 100 Hyprland card1; mkproc 101 Hyprland renderD129; mkproc 200 firefox renderD128
tool --machine
check "awake dGPU with no monitor is flagged"                   'has_problem "card1 (AMD discrete GPU) is powered on although it drives no monitor"'
check "...naming who holds it, but not unrelated GPUs users"    'has_problem "open by: Hyprland" && ! has_problem "open by: .*firefox"'
check "...with the AQ_DRM_DEVICES fix using the integrated card" 'has_problem "AQ_DRM_DEVICES=/dev/dri/by-path/pci-0000:01:00.0-card"'
new_machine gpu-asleep
mkgpu card0 0x1002 1 active; mkgpu card1 0x1002 0 suspended
tool --machine
check "a suspended dGPU is fine"                                '[ "$(printf "%s\n" "$OUT" | grep -c "^PROBLEM|")" -eq 0 ]'
new_machine gpu-on
mkgpu card0 0x1002 1 active; mkgpu card1 0x1002 0 suspended
echo on >"$M/pci/0000:02:00.0/power/control"
tool --machine
check "power/control=on (can never sleep) is flagged"           'has_problem "runtime power management is forced ON"'
new_machine gpu-forced
mkgpu card0 0x1002 1 active
echo high >"$M/pci/0000:01:00.0/power_dpm_force_performance_level"
tool --machine
check "forced GPU clocks are flagged"                           'has_problem "forced to .high."'
echo auto >"$M/pci/0000:01:00.0/power_dpm_force_performance_level"
tool --machine
check "'auto' clocks are fine"                                  '! has_problem "forced to"'
new_machine gpu-nv
mkgpu card0 0x8086 1 active; mkgpu card1 0x10de 0 active
tool --machine
check "awake NVIDIA dGPU with no monitor is flagged"            'has_problem "NVIDIA discrete GPU"'
mkconn card1 HDMI-A-1 connected
tool --machine
check "...but not while it drives a monitor"                    '! has_problem "NVIDIA discrete GPU"'

echo "--- 10. battery charge limit"
new_machine bat1
mkbat 100 Full 100 1
tool status
check "status shows the limit"                                  'printf "%s\n" "$OUT" | grep -q "charge limit: 100%"'
check "tip appears when full and plugged in"                    'printf "%s\n" "$OUT" | grep -q "dot-thermal battery 80"'
tool --machine
check "the tip is not a 'problem'"                              '[ "$(printf "%s\n" "$OUT" | grep -c "^PROBLEM|")" -eq 0 ]'
new_machine bat2
mkbat 70 Discharging 100 0
tool status
check "no tip while on battery"                                 '! printf "%s\n" "$OUT" | grep -q "dot-thermal battery 80"'
new_machine bat3
mkbat 90 Charging - 1
tool status
check "unsupported limit is explained"                          'printf "%s\n" "$OUT" | grep -q "not exposed by this kernel/firmware"'
tool battery 80 --yes
check "setting a limit on unsupported hardware fails clearly"   '[ "$RC" -eq 1 ] && printf "%s\n" "$OUT" | grep -q "doesn.t expose a charge limit"'

new_machine bat4
mkbat 100 Full 100 1
thr="$S/class/power_supply/BAT0/charge_control_end_threshold"
tool battery 80 --dry-run
check "dry run shows the unit but changes nothing"              '[ "$(cat "$thr")" = 100 ] && [ ! -e "$M/units/dot-charge-limit.service" ] && [ ! -s "$ST/calls" ] && printf "%s\n" "$OUT" | grep -q "would write"'
tool battery 80 --yes
check "battery 80 writes the limit now"                         '[ "$(cat "$thr")" = 80 ]'
check "...writes the boot/resume unit"                          'grep -q "echo 80 >" "$M/units/dot-charge-limit.service"'
check "...with \$\$ so systemd does not eat the variable"       'grep -qF "\"\$\$f\"" "$M/units/dot-charge-limit.service"'
check "...re-applied after every kind of sleep"                 'grep -q "^WantedBy=.*suspend.target.*hibernate.target" "$M/units/dot-charge-limit.service"'
check "...reloads systemd and enables the unit"                 'grep -q "sudo systemctl daemon-reload" "$ST/calls" && grep -q "sudo systemctl enable dot-charge-limit.service" "$ST/calls"'
tool battery 60 --yes
check "changing the limit rewrites the unit"                    '[ "$(cat "$thr")" = 60 ] && grep -q "echo 60 >" "$M/units/dot-charge-limit.service" && ! grep -q "echo 80 >" "$M/units/dot-charge-limit.service"'
tool battery off --yes
check "battery off restores 100"                                '[ "$(cat "$thr")" = 100 ]'
check "...and removes the unit"                                 '[ ! -e "$M/units/dot-charge-limit.service" ] && grep -q "sudo systemctl disable dot-charge-limit.service" "$ST/calls"'
tool battery
check "battery with no argument shows status and usage"         '[ "$RC" -eq 0 ] && printf "%s\n" "$OUT" | grep -q "Usage:"'
for bad in 30 101 abc 49; do
    tool battery "$bad" --yes
    check "limit '$bad' is rejected"                            '[ "$RC" -eq 2 ] && [ "$(cat "$thr")" = 100 ]'
done
new_machine nobat
rm -rf "$S/class/power_supply"
tool battery 80 --yes
check "no battery: says so, changes nothing"                    '[ "$RC" -eq 0 ] && printf "%s\n" "$OUT" | grep -q "No battery found"'

echo; echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
