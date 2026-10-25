pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Terse.js" as Terse
import qs.services

// Network state from NetworkManager (nmcli): connection kind and name, the Wi-Fi radio,
// and a scanned list of Wi-Fi networks for the quick settings panel.
Singleton {
    id: root

    property bool available: true
    property bool probed: false            // the first poll has finished (so we know whether nmcli exists)
    property bool hasWifi: false           // an actual Wi-Fi adapter exists (not just the nmcli tool)
    property string kind: "none"          // wifi | ethernet | none
    property string ssid: ""
    property bool wifiEnabled: true
    property var networks: []             // { ssid, signal, secure, active }
    property string connecting: ""        // network being joined right now

    readonly property string label: kind === "wifi" ? (ssid !== "" ? ssid : "Wi-Fi")
                                  : kind === "ethernet" ? "Ethernet"
                                  : (wifiEnabled ? "Not connected" : "Wi-Fi off")

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    readonly property bool scanning: list.running

    // Forces a fresh scan and waits for it (nmcli --rescan yes); if NetworkManager refuses
    // (it rate-limits scans) it falls back to the cached list instead of showing nothing.
    function scan() {
        if (list.running) return;
        list.command = listCommand(true);
        list.running = true;
    }

    function listCommand(rescan) {
        const f = "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list";
        return ["sh", "-c", "command -v nmcli >/dev/null 2>&1 || exit 0; " +
            (rescan ? "out=$(" + f + " --rescan yes 2>/dev/null); [ -n \"$out\" ] || " : "") +
            "out=${out:-$(" + f + " 2>/dev/null)}; printf '%s\\n' \"$out\""];
    }

    function toggleWifi() {
        Run.sh('nmcli radio wifi "$1"', [wifiEnabled ? "off" : "on"]);
        soon.restart();
    }

    function connectTo(name) {
        connecting = name;
        connectTimeout.restart();
        Run.report('nmcli device wifi connect "$1" 2>&1 || { echo "$1 needs a password or is out of range - for a new secured network use nmtui"; exit 1; }', [name], "Wi-Fi");
        soon.restart();
    }

    Process {
        id: poll
        command: ["sh", "-c",
            "command -v nmcli >/dev/null 2>&1 || { echo missing; exit 0; }; " +
            "echo \"radio:$(nmcli radio wifi 2>/dev/null)\"; nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                root.probed = true;
                if (lines[0].trim() === "missing") { root.available = false; return; }
                root.available = true;
                let kind = "none", name = "", wifiDevice = false;
                for (const line of lines) {
                    if (line.startsWith("radio:")) { root.wifiEnabled = line.trim() === "radio:enabled"; continue; }
                    const f = Terse.split(line);
                    if (f.length >= 1 && f[0] === "wifi") wifiDevice = true;
                    if (f.length >= 2 && f[1] === "connected") {
                        if (f[0] === "ethernet") { kind = "ethernet"; name = f[2] ?? ""; break; }
                        if (f[0] === "wifi" && kind !== "ethernet") { kind = "wifi"; name = f[2] ?? ""; }
                    }
                }
                root.hasWifi = wifiDevice;
                root.kind = kind;
                root.ssid = name;
                if (root.connecting !== "" && name === root.connecting) root.connecting = "";
            }
        }
    }

    Process {
        id: list
        command: root.listCommand(false)
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {};
                for (const line of this.text.split("\n")) {
                    if (line.trim() === "") continue;
                    const f = Terse.split(line);
                    const name = f[1] ?? "";
                    if (name === "") continue;
                    const entry = { ssid: name, signal: parseInt(f[2]) || 0, secure: (f[3] ?? "") !== "" && f[3] !== "--", active: f[0] === "*" };
                    const old = best[name];
                    if (!old || entry.active || (!old.active && entry.signal > old.signal)) best[name] = entry;
                }
                const arr = Object.keys(best).map(k => best[k]);
                arr.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                // only replace the list when it really changed, so rows don't rebuild and flicker
                const next = arr.slice(0, 12);
                if (JSON.stringify(next) !== JSON.stringify(root.networks)) root.networks = next;
            }
        }
    }

    // Change notifications: `nmcli monitor` prints a line whenever NetworkManager's state changes
    // (device up/down, connection activated, Wi-Fi radio toggled ...). Any line triggers a refresh a
    // moment later, so the bar follows a change at once instead of up to 20 s late, and the poll
    // below is only a safety net (60 s: if nmcli monitor ever fails to deliver, the bar is at most a minute late). If nmcli exits (NetworkManager restarted) it is started again
    // after a delay that grows to 5 minutes, so a machine without NetworkManager running costs
    // almost nothing.
    property int retryMs: 10000
    property bool monitorOn: true
    Process {
        id: monitor
        running: root.available && root.probed && root.monitorOn
        command: ["nmcli", "monitor"]
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
    Timer { id: debounce; interval: 400; onTriggered: root.refresh() }
    Timer { id: restartMonitor; onTriggered: root.monitorOn = true }

    Timer {
        // Safety net now that nmcli monitor pushes changes: fast while Quick settings is open
        // (the Wi-Fi list lives there), very slow otherwise.
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

    Timer { id: soon; interval: 1200; onTriggered: root.refresh() }
    Timer { id: connectTimeout; interval: 12000; onTriggered: root.connecting = "" }
}
