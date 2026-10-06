import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Omarchy-style bar: a slim full-width slab, flat, monospace.
//   left    menu button, workspaces
//   centre  clock pinned to the exact centre, media flanking it
//   right   tray drawer, updates, night light, do-not-disturb, network, bluetooth,
//           microphone, audio, battery
// Double-click empty bar space to toggle transparency.
PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Style.barHeight
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"

    // The slab. Declared first so widgets sit above its MouseArea.
    Rectangle {
        anchors.fill: parent
        color: ShellState.barTransparent ? "transparent" : Colors.surface
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Colors.outlineVariant
            visible: !ShellState.barTransparent
        }

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: ShellState.barTransparent = !ShellState.barTransparent
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        MenuButton {}
        Workspaces {}
    }

    Clock {
        id: clock
        anchors.centerIn: parent
    }

    Media {
        anchors.right: clock.left
        anchors.rightMargin: Style.gap
        anchors.verticalCenter: parent.verticalCenter
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Tray {}
        UpdatesItem {}
        NightLightItem {}
        Indicators {}
        Network {}
        Bluetooth {}
        MicItem {}
        Audio {}
        Power {}
    }
}
