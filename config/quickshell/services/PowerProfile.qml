pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Power profile (power-saver / balanced / performance) via power-profiles-daemon.
Singleton {
    id: root

    readonly property var order: ["power-saver", "balanced", "performance"]
    property bool available: false
    property string profile: "balanced"

    readonly property string label: profile === "power-saver" ? "Power saver"
                                  : profile === "performance" ? "Performance" : "Balanced"

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    function cycle() {
        const next = order[(order.indexOf(profile) + 1) % order.length];
        profile = next;
        Run.report('powerprofilesctl set "$1" && echo "Profile: $1"', [next], "Power profile");
        soon.restart();
    }

    Process {
        id: poll
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get 2>/dev/null || echo none"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                root.available = root.order.indexOf(t) >= 0;
                if (root.available) root.profile = t;
            }
        }
    }

    Timer {
        // fast while Quick settings is open, slow otherwise (every poll spawns a process)
        interval: ShellState.quickOpen ? 6000 : 30000
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

    Timer { id: soon; interval: 800; onTriggered: root.refresh() }
}
