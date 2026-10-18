import QtQuick
import QtQuick.Layouts
import qs.theme

// icon (click = mute/unmute), slider, percentage.
RowLayout {
    id: root

    property string glyph: ""
    property real value: 0
    property bool muted: false
    property bool showPercent: true

    signal moved(real v)
    signal glyphClicked()

    spacing: 10
    Layout.fillWidth: true

    Txt {
        text: root.glyph
        color: root.muted ? Colors.error : Colors.primary
        font.pixelSize: 17
        horizontalAlignment: Text.AlignHCenter
        Layout.preferredWidth: 26
        MouseArea {
            anchors.fill: parent
            onClicked: root.glyphClicked()
        }
    }

    QSlider {
        Layout.fillWidth: true
        value: root.muted ? 0 : root.value
        fill: root.muted ? Colors.outline : Colors.primary
        onMoved: v => root.moved(v)
    }

    Txt {
        visible: root.showPercent
        text: root.muted ? "mute" : Math.round(root.value * 100) + "%"
        color: Colors.surfaceVariantOn
        font.pixelSize: 13
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 38
    }
}
