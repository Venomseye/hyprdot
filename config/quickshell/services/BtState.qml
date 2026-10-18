pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Bluetooth state from bluetoothctl: radio, connected count and the known devices.
Singleton {
    id: root

    property bool available: false
    property bool powered: false
    property int connected: 0
    property var devices: []              // { mac, name, connected }

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    function togglePower() {
        Run.sh('bluetoothctl power "$1"', [powered ? "off" : "on"]);
        soon.restart();
    }

    function toggleDevice(dev) {
        Run.report(dev.connected ? 'bluetoothctl disconnect "$1"' : 'bluetoothctl connect "$1"', [dev.mac], dev.name);
        soon.restart();
        later.restart();
    }

    Process {
        id: poll
        command: ["sh", "-c",
            "command -v bluetoothctl >/dev/null 2>&1 || { echo missing; exit 0; }; " +
            "p=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}'); echo \"power:${p:-none}\"; " +
            "bluetoothctl devices Connected 2>/dev/null | sed 's/^Device /conn:/'; " +
            "bluetoothctl devices 2>/dev/null | sed 's/^Device /dev:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(l => l.trim()).filter(l => l !== "");
                if (lines.length === 0 || lines[0] === "missing") { root.available = false; return; }
                const connectedMacs = {};
                const all = [];
                let power = "none";
                for (const l of lines) {
                    if (l.startsWith("power:")) power = l.slice(6);
                    else if (l.startsWith("conn:")) connectedMacs[l.slice(5).split(" ")[0]] = true;
                    else if (l.startsWith("dev:")) {
                        const rest = l.slice(4);
                        const sp = rest.indexOf(" ");
                        all.push({ mac: sp < 0 ? rest : rest.slice(0, sp), name: sp < 0 ? rest : rest.slice(sp + 1), connected: false });
                    }
                }
                for (const d of all) d.connected = connectedMacs[d.mac] === true;
                all.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
                root.available = power !== "none";
                root.powered = power === "yes";
                root.connected = Object.keys(connectedMacs).length;
                root.devices = all;
            }
        }
    }

    Timer {
        // fast while Quick settings is open, slow otherwise (every poll spawns a process)
        interval: ShellState.quickOpen ? 8000 : 20000
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
    Timer { id: later; interval: 3000; onTriggered: root.refresh() }
}
