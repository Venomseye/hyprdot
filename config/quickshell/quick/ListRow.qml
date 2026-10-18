import QtQuick
import QtQuick.Layouts
import qs.theme

// One row of a section list (audio output, Wi-Fi network, Bluetooth device).
Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string detail: ""
    property bool active: false
    property int bars: -1               // signal strength 0-100 as little bars; -1 = none

    signal clicked()

    implicitHeight: 34
    radius: 8
    color: active ? Colors.primaryContainer : (area.containsMouse ? Colors.surfaceContainerHigh : "transparent")

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Txt {
            text: root.glyph
            color: root.active ? Colors.primaryContainerOn : Colors.primary
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
        }
        Txt {
            text: root.title
            elide: Text.ElideRight
            color: root.active ? Colors.primaryContainerOn : Colors.surfaceOn
            Layout.fillWidth: true
        }
        SignalBars {
            visible: root.bars >= 0
            signal: root.bars
            tint: root.active ? Colors.primaryContainerOn : Colors.primary
            Layout.alignment: Qt.AlignVCenter
        }
        Txt {
            text: root.detail
            visible: text !== ""
            font.pixelSize: 12
            color: root.active ? Colors.primaryContainerOn : Colors.surfaceVariantOn
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
