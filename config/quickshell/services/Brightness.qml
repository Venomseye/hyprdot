pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Screen backlight via brightnessctl. `available` is false on desktops and VMs
// without a backlight, and the quick settings slider hides itself.
Singleton {
    id: root

    property real level: 0          // 0..1
    property bool available: false
    property double lastSet: 0

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    function set(v) {
        const clamped = Math.max(0.01, Math.min(1, v));     // never all the way to black
        level = clamped;
        lastSet = Date.now();
        Run.sh('brightnessctl -q -c backlight set "$1%"', [String(Math.round(clamped * 100))]);
    }

    Process {
        id: poll
        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 || { echo none; exit 0; }; brightnessctl -c backlight -m 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(",");
                if (parts.length < 4) { root.available = false; return; }
                root.available = true;
                // a poll right after you moved the slider must not make it jump back
                if (Date.now() - root.lastSet > 1500) root.level = (parseInt(parts[3]) || 0) / 100;
            }
        }
    }

    Timer {
        // fast while Quick settings is open, slow otherwise (every poll spawns a process)
        interval: ShellState.quickOpen ? 5000 : 90000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // opening the panel shows fresh values straight away
    Connections {
        target: ShellState
        function onQuickOpenChanged() { if (ShellState.quickOpen) root.refresh(); }
    }
}
