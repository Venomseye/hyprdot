import QtQuick
import qs.theme

// Round icon button for the media pill. `filled` = the primary play/pause button.
Rectangle {
    id: root

    property string glyph: ""
    property int size: 36
    property int glyphSize: 16
    property bool filled: false
    property color hoverColor: Colors.surfaceContainerHighest
    readonly property bool hovered: area.containsMouse

    signal clicked()

    implicitWidth: root.size
    implicitHeight: root.size
    radius: width / 2
    color: root.filled
        ? (area.containsMouse ? Colors.primaryContainer : Colors.primary)
        : (area.containsMouse ? root.hoverColor : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    Txt {
        anchors.centerIn: parent
        text: root.glyph
        font.pixelSize: root.glyphSize
        horizontalAlignment: Text.AlignHCenter
        color: root.filled
            ? (area.containsMouse ? Colors.primaryContainerOn : Colors.primaryOn)
            : Colors.surfaceOn
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
