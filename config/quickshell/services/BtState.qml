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
            // bluetoothctl waits for bluetoothd when it is not running; without a time limit that wait never ends,
            // the poll never finishes, and the tile stays hidden even after the service is started
            "command -v timeout >/dev/null 2>&1 || timeout() { shift; $@; }; " +
            "p=$(timeout 5 bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}'); echo \"power:${p:-none}\"; " +
            "timeout 5 bluetoothctl devices Connected 2>/dev/null | sed 's/^Device /conn:/'; " +
            "timeout 5 bluetoothctl devices 2>/dev/null | sed 's/^Device /dev:/'"]
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

    // Change notifications from BlueZ over D-Bus: a device connecting/disconnecting or the adapter being
    // switched on/off emits PropertiesChanged. Any such signal triggers a refresh a moment later, so
    // the bar follows at once. dbus-monitor on the system bus works for signals without root; if it
    // ever does not (or is missing), the poll below still keeps the state fresh, only slower.
    // `exec` makes the shell BECOME dbus-monitor, so stopping the process cannot leave one behind;
    // stdbuf -oL stops its output from being held back in a pipe buffer.
    property int retryMs: 10000
    property bool monitorOn: true
    Process {
        id: monitor
        running: root.available && root.monitorOn
        command: ["sh", "-c", "command -v dbus-monitor >/dev/null 2>&1 || exit 3; " +
            "if command -v stdbuf >/dev/null 2>&1; then exec stdbuf -oL dbus-monitor --system " +
            "\"type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'\" " +
            "\"type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Adapter1'\"; fi; " +
            "exec dbus-monitor --system " +
            "\"type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'\" " +
            "\"type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Adapter1'\""]
        stdout: SplitParser {
            onRead: data => {
                root.retryMs = 10000;
                debounce.restart();
            }
        }
        onExited: {
            root.monitorOn = false;
            restartMonitor.interval = root.retryMs;
            root.retryMs = Math.min(root.retryMs * 3, 300000);
            restartMonitor.start();
        }
    }
    Timer { id: debounce; interval: 600; onTriggered: root.refresh() }
    Timer { id: restartMonitor; onTriggered: root.monitorOn = true }

    Timer {
        // Safety net now that BlueZ pushes changes: fast while Quick settings is open (the device
        // list lives there), slow otherwise.
        interval: ShellState.quickOpen ? 10000 : 60000
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
