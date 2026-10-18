pragma Singleton

import QtQuick
import Quickshell

// Runs shell commands for the UI with ~/.local/bin on PATH (dot-reload, dot-power ...
// live there and the session's PATH often lacks it). Shared by the menu, the quick
// settings panel and the wallpaper picker.
Singleton {
    // exec(command, title, report)
    //   report = true: the output (or failure) comes back as a notification - these run
    //   with no terminal, so silence would look like "broken".
    function exec(action, title, report) {
        if (!action) return;
        const bin = action.trim().split(/\s+/)[0];
        const check = 'PATH="$HOME/.local/bin:$PATH"; export PATH; ' +
            'if ! command -v "$1" >/dev/null 2>&1; then ' +
            'command -v notify-send >/dev/null 2>&1 && notify-send -u critical "$3" "$1 is not installed (run install.sh)"; exit 127; fi; ';
        const body = report
            ? 'out="$(eval "$2" 2>&1)"; rc=$?; msg="$(printf "%s" "$out" | tail -n 4)"; ' +
              'if [ $rc -eq 0 ]; then notify-send -a menu "$3" "${msg:-Done}"; ' +
              'else notify-send -u critical -a menu "$3 failed" "${msg:-exit code $rc}"; fi'
            : 'eval "$2"';
        Quickshell.execDetached(["sh", "-c", check + body, "sh", bin, action, title || "Command"]);
    }

    // report(script, args, title): like exec(), for a script that uses $1, $2 ... for its arguments.
    // Success or failure comes back as a notification titled `title`.
    function report(script, args, title) {
        const body = 'T="$1"; shift; out="$( { ' + script + ' ; } 2>&1 )"; rc=$?; ' +
            'msg="$(printf "%s" "$out" | tail -n 4)"; ' +
            'if [ $rc -eq 0 ]; then notify-send -a shell "$T" "${msg:-Done}"; ' +
            'else notify-send -u critical -a shell "$T failed" "${msg:-exit code $rc}"; fi';
        Quickshell.execDetached(["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; export PATH; ' + body, "sh", title || "Command"].concat(args || []));
    }

    // sh(script, args...): run a small script with $1, $2 ... = args (no quoting worries).
    function sh(script, args) {
        Quickshell.execDetached(["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; export PATH; ' + script, "sh"].concat(args || []));
    }
}
