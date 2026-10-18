import QtQuick
import QtQuick.Layouts
import qs.theme

// A toggle tile: icon, label, one line of state. Filled when `active`.
Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    property bool compact: false     // tighter padding for one-word shortcut tiles

    signal clicked()

    implicitHeight: 54
    radius: 10
    color: active ? Colors.primaryContainer : Colors.surfaceContainerHigh
    border.width: area.containsMouse ? 1 : 0
    border.color: Colors.primary
    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 8 : 12
        anchors.rightMargin: root.compact ? 8 : 10
        spacing: root.compact ? 8 : 10

        // Compact tiles centre their icon + label as one group: these two spacers share the
        // leftover width equally. They are invisible (so ignored) in the normal two-line tiles.
        Item {
            visible: root.compact
            Layout.fillWidth: true
        }

        Txt {
            text: root.glyph
            font.pixelSize: 18
            color: root.active ? Colors.primaryContainerOn : Colors.surfaceVariantOn
            Layout.preferredWidth: 22
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: !root.compact
            Layout.alignment: Qt.AlignVCenter

            Txt {
                text: root.label
                font.bold: true
                font.pixelSize: 13
                color: root.active ? Colors.primaryContainerOn : Colors.surfaceOn
                elide: Text.ElideRight
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
            }
            Txt {
                text: root.sub
                visible: text !== ""
                font.pixelSize: 12
                color: root.active ? Colors.primaryContainerOn : Colors.surfaceVariantOn
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Item {
            visible: root.compact
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
