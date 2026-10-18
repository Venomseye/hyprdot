import QtQuick
import qs.theme

// Horizontal slider, value 0..1. Click or drag to set; the wheel nudges by 5%.
// It never changes `value` itself - it emits moved(v) and the owner decides.
Item {
    id: root

    property real value: 0
    property color fill: Colors.primary

    signal moved(real v)

    implicitHeight: 24

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Colors.surfaceContainerHigh

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 3
            color: root.fill
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round((root.width - width) * Math.max(0, Math.min(1, root.value)))
        color: root.fill
        border.width: 2
        border.color: Colors.surface
    }

    MouseArea {
        anchors.fill: parent
        function setFrom(mx) { root.moved(Math.max(0, Math.min(1, mx / width))); }
        onPressed: mouse => setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x); }
        onWheel: wheel => {
            root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))));
            wheel.accepted = true;
        }
    }
}
