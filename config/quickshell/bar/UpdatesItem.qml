import QtQuick
import qs.theme
import qs.services

// System updates. Dim check = up to date, accent arrow + count = updates
// waiting, red triangle = the check failed. Hidden while up to date (a permanent check mark
// was clutter) and on distros dot-updates doesn't know.
// left = run the updater in a terminal, right = check now.
BarItem {
    visible: UpdateCheck.state === "updates" || UpdateCheck.state === "error"
    tooltip: UpdateCheck.state === "updates" ? UpdateCheck.count + " updates available\nclick: install   right-click: check now"
           : UpdateCheck.state === "ok" ? "System is up to date\nright-click: check now"
           : UpdateCheck.state === "checking" ? "Checking for updates..."
           : "Update check failed: " + UpdateCheck.detail

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) UpdateCheck.refresh();
        else if (mouse.button === Qt.LeftButton) UpdateCheck.install();
    }

    BarIcon {
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
        font.pixelSize: 12
    }
}
