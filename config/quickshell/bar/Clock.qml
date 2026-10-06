import QtQuick
import Quickshell
import qs.theme
import qs.services

// left = calendar popup, right = cycle the format. The bar pins this to the
// exact centre and flanks it with the media widget.
BarItem {
    id: root

    readonly property var formats: [
        "HH:mm",
        "ddd, dd MMM hh:mm AP",
        "ddd dd MMM  HH:mm",
        "yyyy-MM-dd HH:mm"
    ]

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            ShellState.clockFormat = (ShellState.clockFormat + 1) % formats.length;
        } else {
            popup.toggle(root.QsWindow.window, root.mapToItem(null, root.width / 2, 0).x);
        }
    }

    Txt {
        text: Qt.formatDateTime(clock.date, root.formats[ShellState.clockFormat % root.formats.length])
        font.bold: true
    }

    ClockPopup { id: popup }
}
