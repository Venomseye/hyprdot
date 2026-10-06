pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Night light via hyprsunset. "On" means a hyprsunset process is running;
// toggling starts it at Style.nightLightKelvin or stops it (which restores
// normal colours). Polled every 3s so it also follows hyprsunset you start
// yourself. If you run hyprsunset on a schedule from autostart, it will always
// read as "on" - this toggle is for manual use.
Singleton {
    id: root

    property bool active: false
    property bool available: true

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    function toggle() {
        if (!available) {
            Quickshell.execDetached(["sh", "-c", "command -v notify-send >/dev/null 2>&1 && notify-send -u critical 'Night light' 'hyprsunset is not installed'"]);
            return;
        }
        Quickshell.execDetached([
            "sh", "-c",
            active ? "pkill -x hyprsunset" : 'setsid -f hyprsunset -t "$1" >/dev/null 2>&1 </dev/null',
            "sh", String(Style.nightLightKelvin)
        ]);
        soon.restart();
    }

    Process {
        id: poll
        command: ["sh", "-c",
            "command -v hyprsunset >/dev/null 2>&1 || { echo missing; exit 0; }; " +
            "pgrep -x hyprsunset >/dev/null 2>&1 && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                root.available = t !== "missing";
                root.active = t === "on";
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: soon
        interval: 600
        onTriggered: root.refresh()
    }
}
