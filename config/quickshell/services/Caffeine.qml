pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// "Stay awake": stops hypridle so the screen doesn't dim or lock; turning it off
// starts hypridle again. (It also comes back on its own at the next login.)
Singleton {
    id: root

    property bool available: false
    property bool active: false          // true = hypridle stopped = staying awake

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    function toggle() {
        if (!available) {
            Run.sh("notify-send -u critical 'Stay awake' 'hypridle is not installed'");
            return;
        }
        Run.sh(active ? "setsid -f hypridle >/dev/null 2>&1 </dev/null" : "pkill -x hypridle");
        soon.restart();
    }

    Process {
        id: poll
        command: ["sh", "-c", "command -v hypridle >/dev/null 2>&1 || { echo missing; exit 0; }; pgrep -x hypridle >/dev/null 2>&1 && echo running || echo stopped"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                root.available = t !== "missing";
                root.active = t === "stopped";
            }
        }
    }

    Timer {
        // fast while Quick settings is open, slow otherwise (every poll spawns a process)
        interval: ShellState.quickOpen ? 3000 : 90000
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

    Timer { id: soon; interval: 600; onTriggered: root.refresh() }
}
