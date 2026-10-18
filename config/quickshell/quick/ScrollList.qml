import QtQuick
import qs.theme

// A list region with a maximum height that scrolls (wheel or drag) when it is longer,
// so an expanded Wi-Fi/Bluetooth list can never push the panel off the screen.
// Children are laid out in a column and should size themselves with width: parent.width.
Flickable {
    id: root

    property int maxHeight: 216
    default property alias content: col.data

    implicitHeight: Math.min(col.implicitHeight, maxHeight)
    contentWidth: width
    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: col.implicitHeight > maxHeight

    Column {
        id: col
        width: root.width
        spacing: 2
    }
}
