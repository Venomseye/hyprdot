import QtQuick
import Quickshell
import qs.theme
import qs.services

// Bluetooth icon (state from BtState, polled with bluetoothctl).
// left = quick settings (device list there), right = turn the radio on/off,
// middle = blueman-manager.
BarItem {
    visible: BtState.available
    tooltip: !BtState.powered ? "Bluetooth off\nright-click: turn on"
           : BtState.connected > 0 ? "Bluetooth: " + BtState.connected + " connected\nright-click: turn off"
           : "Bluetooth on, nothing connected\nright-click: turn off"

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) BtState.togglePower();
        else if (mouse.button === Qt.MiddleButton)
            Quickshell.execDetached(["sh", "-c", "command -v blueman-manager >/dev/null 2>&1 && exec blueman-manager"]);
        else ShellState.toggleQuick();
    }

    BarIcon {
        text: "\uf293"
        color: !BtState.powered ? Colors.outline : BtState.connected > 0 ? Colors.primary : Colors.surfaceOn
    }
    Txt {
        visible: BtState.connected > 0
        text: BtState.connected
        color: Colors.primary
        font.pixelSize: 12
    }
}
