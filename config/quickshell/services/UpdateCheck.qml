pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pending system updates, via the distro-aware `dot-updates` helper
// (Arch + AUR, Debian/Ubuntu, Fedora/RHEL, openSUSE, Void, Alpine).
// Checks at start and every 30 minutes; refresh() forces one.
Singleton {
    id: root

    property int count: 0
    property string state: "checking"     // checking | ok | updates | error | unsupported
    property string detail: ""

    // Bar sessions often lack ~/.local/bin in PATH, so fall back to it.
    readonly property string helper: 'command -v dot-updates >/dev/null 2>&1 && exec dot-updates "$@"; exec "$HOME/.local/bin/dot-updates" "$@"'

    function parse(out) {
        const t = out.trim();
        if (/^\d+$/.test(t)) {
            count = parseInt(t);
            state = count > 0 ? "updates" : "ok";
            detail = "";
        } else if (t.startsWith("unsupported")) {
            state = "unsupported";
            detail = t;
        } else {
            state = "error";
            detail = t;
        }
    }

    function refresh() {
        if (checker.running) return;
        if (state === "error") state = "checking";
        checker.running = true;
    }

    // Opens the update command in a terminal window.
    function install() {
        Quickshell.execDetached(["sh", "-c", helper, "sh", "--run"]);
        later.restart();
    }

    Process {
        id: checker
        command: ["sh", "-c", root.helper, "sh", "--bar"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Re-check a couple of minutes after you launched the updater.
    Timer {
        id: later
        interval: 120000
        onTriggered: root.refresh()
    }
}
