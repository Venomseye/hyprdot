import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.services

// 1-5 always shown; higher ones only while they exist or are active on this screen.
// Each bar highlights the workspace that is active ON ITS OWN monitor (with two screens
// they differ). left = go there, scroll = previous/next.
Item {
    id: root

    readonly property var mon: Hyprland.monitorFor(root.QsWindow.window ? root.QsWindow.window.screen : null)

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
            if (step !== 0) Compositor.focusWorkspace(step < 0 ? "e-1" : "e+1");
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
                readonly property bool shownHere: root.mon?.activeWorkspace?.id === ws.wsId
                readonly property bool focused: shownHere && (root.mon?.focused ?? false)
                readonly property bool urgent: info?.urgent ?? false

                visible: wsId <= 5 || occupied || shownHere
                width: 26
                height: Style.barHeight

                Txt {
                    anchors.centerIn: parent
                    text: ws.wsId
                    font.bold: ws.focused
                    color: ws.urgent ? Colors.error
                         : ws.shownHere ? Colors.primary
                         : ws.occupied ? Colors.surfaceOn
                         : Colors.outline
                }

                Rectangle {
                    visible: ws.shownHere
                    opacity: ws.focused ? 1 : 0.45
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 14
                    height: 3
                    radius: 1
                    color: Colors.primary
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Compositor.focusWorkspace(ws.wsId)
                }
            }
        }
    }
}
