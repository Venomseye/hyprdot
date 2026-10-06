import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Wi-Fi / Ethernet from `nmcli` (polled every 5s). left = nmtui in a floating
// terminal (see the float-nmtui rule in hypr/rules.lua).
BarItem {
    id: root

    property string kind: "none"   // wifi | ethernet | none
    property bool available: true

    visible: available

    function parse(out) {
        if (out.trim() === "missing") { available = false; return; }
        const lines = out.split("\n");
        if (lines.some(l => l.startsWith("ethernet:connected"))) kind = "ethernet";
        else if (lines.some(l => l.startsWith("wifi:connected"))) kind = "wifi";
        else kind = "none";
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            Quickshell.execDetached(["sh", "-c", "command -v nmtui >/dev/null 2>&1 && exec kitty --title=nmtui -e nmtui"]);
    }

    Process {
        id: poll
        command: ["sh", "-c", "command -v nmcli >/dev/null 2>&1 && nmcli -t -f TYPE,STATE device || echo missing"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    Txt {
        text: root.kind === "ethernet" ? "\uf0e8" : "\uf1eb"
        color: root.kind === "none" ? Colors.error : Colors.surfaceOn
    }
}
