import QtQuick
import qs.theme
import qs.services

// System updates. Dim check = up to date, accent arrow + count = updates
// waiting, red triangle = the check failed. Hidden on distros dot-updates
// doesn't know.
// left = run the updater in a terminal, right = check now.
BarItem {
    visible: UpdateCheck.state !== "unsupported"

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) UpdateCheck.refresh();
        else if (mouse.button === Qt.LeftButton) UpdateCheck.install();
    }

    Txt {
        text: UpdateCheck.state === "updates" ? "\uf019"
            : UpdateCheck.state === "error" ? "\uf071"
            : UpdateCheck.state === "checking" ? "\uf021"
            : "\uf00c"
        color: UpdateCheck.state === "updates" ? Colors.primary
             : UpdateCheck.state === "error" ? Colors.error
             : Colors.surfaceVariantOn
    }
    Txt {
        visible: UpdateCheck.state === "updates"
        text: UpdateCheck.count
        color: Colors.primary
        font.pixelSize: 11
    }
}
