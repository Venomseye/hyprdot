import QtQuick
import Quickshell.Hyprland
import qs.theme

// 1-5 always shown; higher ones only while they exist or are focused.
// left = focus, scroll = previous/next.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: Style.barHeight

    property real scrollAcc: 0

    // Declared before the Row so each workspace's own MouseArea (which has no
    // onWheel) lets wheel events fall through to this one.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const dy = wheel.angleDelta.y;
            let step = 0;
            if (Math.abs(dy) >= 120) {
                step = dy > 0 ? -1 : 1;
                root.scrollAcc = 0;
            } else {
                root.scrollAcc += dy !== 0 ? dy : wheel.pixelDelta.y * 3;
                if (Math.abs(root.scrollAcc) >= 60) {
                    step = root.scrollAcc > 0 ? -1 : 1;
                    root.scrollAcc = 0;
                }
            }
            if (step !== 0) Hyprland.dispatch("workspace " + (step < 0 ? "e-1" : "e+1"));
            wheel.accepted = true;
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: 10

            delegate: Item {
                id: ws

                required property int index
                readonly property int wsId: index + 1
                readonly property var info: Hyprland.workspaces.values.find(w => w.id === ws.wsId)
                readonly property bool occupied: info !== undefined
                readonly property bool focused: Hyprland.focusedWorkspace?.id === ws.wsId
                readonly property bool urgent: info?.urgent ?? false

                visible: wsId <= 5 || occupied || focused
                width: 22
                height: Style.barHeight

                Txt {
                    anchors.centerIn: parent
                    text: ws.wsId
                    font.bold: ws.focused
                    color: ws.urgent ? Colors.error
                         : ws.focused ? Colors.primary
                         : ws.occupied ? Colors.surfaceOn
                         : Colors.outline
                }

                Rectangle {
                    visible: ws.focused
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 12
                    height: 2
                    radius: 1
                    color: Colors.primary
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + ws.wsId)
                }
            }
        }
    }
}
