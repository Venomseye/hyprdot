import QtQuick
import Quickshell
import qs.theme
import qs.services

// Wi-Fi / Ethernet icon (state from NetState, polled with nmcli).
// left = quick settings (Wi-Fi list there), right = nmtui in a floating terminal.
BarItem {
    visible: NetState.available
    tooltip: (NetState.kind === "none" ? NetState.label : "Connected: " + NetState.label) + "\nclick: quick settings   right-click: nmtui"

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            Quickshell.execDetached(["sh", "-c", "command -v nmtui >/dev/null 2>&1 && exec kitty --title=nmtui -e nmtui"]);
        else if (mouse.button === Qt.LeftButton)
            ShellState.toggleQuick();
    }

    BarIcon {
        text: NetState.kind === "ethernet" ? "\uf0ac" : "\uf1eb"
        color: !NetState.wifiEnabled && NetState.kind === "none" ? Colors.outline
             : NetState.kind === "none" ? Colors.error
             : Colors.surfaceOn
    }
}
