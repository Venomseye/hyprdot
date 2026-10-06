import QtQuick
import Quickshell
import qs.theme
import qs.services

// left = Omarchy-style menu / launcher, right = terminal
BarItem {
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            Quickshell.execDetached(["sh", "-c", "command -v kitty >/dev/null 2>&1 && exec kitty; command -v ghostty >/dev/null 2>&1 && exec ghostty"]);
        else
            ShellState.toggleMenu();
    }

    Txt {
        text: "\uf303"
        color: Colors.primary
        font.pixelSize: 16
    }
}
