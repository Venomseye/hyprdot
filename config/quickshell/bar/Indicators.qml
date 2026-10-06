import QtQuick
import qs.theme
import qs.services

// State indicators that only appear while active.
// Do Not Disturb: left = turn it off.
BarItem {
    visible: ShellState.dnd
    onClicked: ShellState.dnd = false

    Txt {
        text: "\uf1f6"
        color: Colors.tertiary
    }
}
