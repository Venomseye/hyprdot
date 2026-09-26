#!/usr/bin/env bash
#
# Traces the wallpaper -> matugen -> app-colors pipeline step by step, so
# whichever link is actually broken shows up clearly instead of a vague
# "colors don't match." Run this, then change your wallpaper (SUPER+SHIFT+W,
# then l or h), and watch the output.
#
# I verified every piece of this pipeline against official documentation
# (wpaperd's README, matugen's wiki, waybar's man page) and each one is
# correct on paper. This script exists because "correct on paper" and
# "actually happening on your machine" are two different claims, and I
# can't observe your machine directly.

set -uo pipefail

echo "=== 1. Is wpaperd actually running, and with which config? ==="
pgrep -a wpaperd || echo "  !! wpaperd is not running at all"
echo

echo "=== 2. Current wallpaper symlink (maintained by the hook) ==="
ls -la ~/.cache/current-wallpaper 2>/dev/null || echo "  Not created yet - the hook has never successfully run"
echo

echo "=== 3. matugen hook log - the ground truth for whether matugen ran ==="
if [ -f ~/.cache/matugen-hook.log ]; then
    echo "  Last 20 lines:"
    tail -20 ~/.cache/matugen-hook.log | sed 's/^/    /'
else
    echo "  !! No log file at all - matugen-hook.sh has never been invoked."
    echo "     That points at wpaperd's own config, not matugen. Check:"
    echo "     cat ~/.config/wpaperd/config.toml   (is 'exec' set, and does the path exist?)"
fi
echo

echo "=== 4. Did the generated CSS actually change? (mtime + a live value) ==="
if [ -f ~/.config/waybar/waybar-colors.css ]; then
    stat -c '  waybar-colors.css last modified: %y' ~/.config/waybar/waybar-colors.css
    grep '@define-color highlight' ~/.config/waybar/waybar-colors.css | sed 's/^/  /'
else
    echo "  !! waybar-colors.css does not exist - matugen's waybar template never ran"
fi
echo

echo "=== 5. Is your RUNNING waybar new enough to have reload_style_on_change active? ==="
WAYBAR_PID=$(pgrep -x waybar | head -1)
if [ -n "$WAYBAR_PID" ]; then
    START=$(ps -o lstart= -p "$WAYBAR_PID")
    echo "  waybar (PID $WAYBAR_PID) has been running since: $START"
    echo "  reload_style_on_change is read ONCE at waybar's own startup."
    echo "  If that start time is before you installed this config, this waybar"
    echo "  process does NOT have that setting active, no matter what the file"
    echo "  says now. Fix: killall waybar && waybar &  (a full restart, not SIGUSR2)"
else
    echo "  !! waybar isn't running"
fi
echo

echo "=== 6. Manual, isolated matugen test - bypasses wpaperd entirely ==="
echo "  Run this with a real wallpaper path to test matugen on its own:"
echo "    matugen image ~/Pictures/Wallpapers/<somefile> --source-color-index 0 </dev/null"
echo "  Watch for errors directly in the terminal. If this works but changing"
echo "  wallpaper through Hyprland doesn't, the break is between wpaperd and"
echo "  the hook script, not in matugen itself."
