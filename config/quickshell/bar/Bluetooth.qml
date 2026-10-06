import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Bluetooth from `bluetoothctl` (polled every 8s).
// left = blueman-manager, right = toggle the radio.
BarItem {
    id: root

    property bool available: false
    property bool powered: false
    property int connected: 0

    visible: available

    function parse(out) {
        const t = out.trim();
        if (t === "missing" || t === "") { available = false; return; }
        const parts = t.split(" ");
        available = parts[0] !== "none";
        powered = parts[0] === "yes";
        connected = parseInt(parts[1] ?? "0") || 0;
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            Quickshell.execDetached(["sh", "-c", "bluetoothctl power " + (root.powered ? "off" : "on")]);
            refresh.start();
        } else if (mouse.button === Qt.LeftButton) {
            Quickshell.execDetached(["sh", "-c", "command -v blueman-manager >/dev/null 2>&1 && exec blueman-manager"]);
        }
    }

    Process {
        id: poll
        command: ["sh", "-c",
            "command -v bluetoothctl >/dev/null 2>&1 || { echo missing; exit 0; }; " +
            "p=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}'); " +
            "n=$(bluetoothctl devices Connected 2>/dev/null | grep -c '^Device'); " +
            "echo \"${p:-none} $n\""]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    Timer {
        id: refresh
        interval: 800
        onTriggered: if (!poll.running) poll.running = true
    }

    Txt {
        text: "\uf293"
        color: !root.powered ? Colors.outline : root.connected > 0 ? Colors.primary : Colors.surfaceOn
    }
    Txt {
        visible: root.connected > 0
        text: root.connected
        color: Colors.primary
        font.pixelSize: 11
    }
}
