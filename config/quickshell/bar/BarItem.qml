import QtQuick
import QtQuick.Layouts
import qs.theme

// Base for every bar widget: padded row, hover highlight, click + scroll.
Item {
    id: root

    default property alias content: row.data
    property bool interactive: true
    property int horizontalPadding: 8
    readonly property bool hovered: area.containsMouse
    property real scrollAcc: 0

    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: Style.barHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: 6
        color: root.interactive && root.hovered ? Colors.surfaceContainerHigh : "transparent"
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => root.clicked(mouse)

        // MouseArea.onWheel rather than WheelHandler: it is the long-standing,
        // reliable path on layer-shell windows. Emits scrolled(+-120) per step.
        onWheel: wheel => {
            const dy = wheel.angleDelta.y;
            if (Math.abs(dy) >= 120) {
                root.scrolled(dy > 0 ? 120 : -120);       // mouse wheel notch
                root.scrollAcc = 0;
            } else {
                root.scrollAcc += dy !== 0 ? dy : wheel.pixelDelta.y * 3;   // touchpad
                if (Math.abs(root.scrollAcc) >= 60) {
                    root.scrolled(root.scrollAcc > 0 ? 120 : -120);
                    root.scrollAcc = 0;
                }
            }
            wheel.accepted = true;
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
