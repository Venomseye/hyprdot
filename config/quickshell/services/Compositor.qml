pragma Singleton

import QtQuick
import Quickshell

// Talks to Hyprland for the shell. With a Lua config `hyprctl dispatch` takes a Lua
// expression, not the old "workspace 3" strings, so every call goes through here.
Singleton {
    // focusWorkspace(3) or focusWorkspace("e+1") / "e-1" / "empty"
    function focusWorkspace(target) {
        const arg = typeof target === "number" ? String(target) : '"' + target + '"';
        Run.sh('hyprctl dispatch "hl.dsp.focus({ workspace = $1 })"', [arg]);
    }
}
