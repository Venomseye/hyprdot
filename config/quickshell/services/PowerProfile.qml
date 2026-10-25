pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Power profile via power-profiles-daemon. Which profiles exist depends on the hardware driver:
// "performance" is only offered when the CPU/platform driver supports it (many desktops and VMs
// only have power-saver and balanced), and `powerprofilesctl set performance` then fails with
// "invalid choice". So the list is read from the daemon instead of assumed.
Singleton {
    id: root

    // display / cycling order; only the ones the daemon reports are used
    readonly property var order: ["power-saver", "balanced", "performance"]
    property var profiles: []           // supported on this machine, in `order`
    property bool available: false      // needs at least two to be worth a tile
    property string profile: "balanced"

    readonly property string label: profile === "power-saver" ? "Power saver"
                                  : profile === "performance" ? "Performance" : "Balanced"

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    function cycle() {
        if (root.profiles.length < 2) return;
        const i = root.profiles.indexOf(root.profile);
        const next = root.profiles[(i + 1) % root.profiles.length];
        root.profile = next;
        Run.report('powerprofilesctl set "$1" && echo "Profile: $1"', [next], "Power profile");
        soon.restart();
    }

    Process {
        id: poll
        // prints:  current=<profile>   and one  profile=<name>  line per supported profile
        command: ["sh", "-c", [
            "command -v powerprofilesctl >/dev/null 2>&1 || { echo none; exit 0; }",
            "cur=$(powerprofilesctl get 2>/dev/null) || { echo none; exit 0; }",
            "echo \"current=$cur\"",
            "powerprofilesctl list 2>/dev/null | grep -E '^[ *]*[a-z-]+:[[:space:]]*$' | sed 's/[^a-z-]//g; s/^/profile=/'"
        ].join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                let cur = "";
                const found = [];
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("current=")) cur = line.slice(8).trim();
                    else if (line.startsWith("profile=")) found.push(line.slice(8).trim());
                }
                // If the list could not be read (format change), assume only the two profiles
                // the daemon always has, plus the current one: never offer something that errors.
                let supported = root.order.filter(p => found.indexOf(p) >= 0);
                if (supported.length === 0 && cur !== "") {
                    supported = root.order.filter(p => p !== "performance" || p === cur);
                }
                root.profiles = supported;
                root.available = supported.length >= 2 && supported.indexOf(cur) >= 0;
                if (root.available) root.profile = cur;
            }
        }
    }

    Timer {
        // fast while Quick settings is open, slow otherwise (every poll spawns a process)
        interval: ShellState.quickOpen ? 6000 : 90000
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
