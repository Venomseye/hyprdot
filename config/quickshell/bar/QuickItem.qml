import QtQuick
import qs.theme
import qs.services

// Opens the quick settings panel (volume, brightness, toggles, Wi-Fi, Bluetooth, audio output).
BarItem {
    tooltip: "Quick settings   (Super+A)"
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) ShellState.toggleQuick();
    }

    BarIcon {
        text: "\uf1de"
        color: ShellState.quickOpen ? Colors.primary : Colors.surfaceOn
    }
}
