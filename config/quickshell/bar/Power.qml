import QtQuick
import Quickshell
import qs.theme
import qs.services

// Battery. left = btop in a floating terminal, right = toggle the percentage.
BarItem {
    visible: Battery.present

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            ShellState.batteryPercent = !ShellState.batteryPercent;
        else
            Quickshell.execDetached(["sh", "-c", "command -v btop >/dev/null 2>&1 && exec kitty --title=btop -e btop"]);
    }

    Txt {
        text: Battery.glyph
        color: Battery.low ? Colors.error : Battery.charging ? Colors.primary : Colors.surfaceOn
    }
    Txt {
        visible: ShellState.batteryPercent
        text: Battery.percent + "%"
        color: Battery.low ? Colors.error : Colors.surfaceOn
    }
}
