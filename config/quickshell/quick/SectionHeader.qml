import QtQuick
import QtQuick.Layouts
import qs.theme

// Collapsible section title. The current value (output device, Wi-Fi network) sits on a
// second line so long names such as "Navi 10 HDMI Audio HDMI / DisplayPort" are not cut
// off next to the title.
Rectangle {
    id: root

    property string label: ""
    property string sub: ""
    property bool expanded: false

    signal clicked()

    implicitHeight: root.sub !== "" ? 50 : 36
    radius: 8
    color: area.containsMouse ? Colors.surfaceContainerHigh : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            Txt {
                text: root.label
                font.bold: true
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            Txt {
                text: root.sub
                visible: text !== ""
                color: Colors.surfaceVariantOn
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        Txt {
            text: root.expanded ? "\uf107" : "\uf105"
            color: Colors.surfaceVariantOn
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
