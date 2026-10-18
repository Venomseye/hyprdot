import QtQuick
import qs.theme

// Four little bars for a signal strength 0-100.
Row {
    id: root

    property int signal: 0
    property color tint: Colors.primary
    readonly property int lit: signal >= 75 ? 4 : signal >= 50 ? 3 : signal >= 25 ? 2 : signal > 0 ? 1 : 0

    spacing: 2
    height: 12

    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            width: 3
            height: 4 + index * 3
            y: root.height - height
            radius: 1
            color: index < root.lit ? root.tint : Colors.outlineVariant
        }
    }
}
