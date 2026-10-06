import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.theme

// Volume OSD: a small pill at the bottom of the screen for 1.5s whenever the
// default sink's volume or mute state changes (keys, bar scroll, pavucontrol).
Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    property bool armed: false      // ignore the initial values at startup
    property bool showing: false
    property real level: 0
    property bool muted: false

    PwObjectTracker { objects: [root.sink] }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.showing = false
    }

    function pulse() {
        if (!armed || !sink?.audio) return;
        level = sink.audio.volume;
        muted = sink.audio.muted;
        showing = true;
        hide.restart();
    }

    Connections {
        target: root.sink?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() { root.pulse(); }
        function onMutedChanged() { root.pulse(); }
    }

    PanelWindow {
        visible: root.showing
        anchors.bottom: true
        margins.bottom: 90
        implicitWidth: 300
        implicitHeight: 46
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}      // click-through
        WlrLayershell.namespace: "qs-osd"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            anchors.fill: parent
            radius: Style.radius
            color: Colors.surfaceContainer
            border.width: 1
            border.color: Colors.outlineVariant

            Txt {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.muted ? "\uf026" : root.level < 0.34 ? "\uf027" : "\uf028"
                color: root.muted ? Colors.error : Colors.primary
                font.pixelSize: 18
            }

            Rectangle {
                id: track
                anchors.left: icon.right
                anchors.leftMargin: 14
                anchors.right: pct.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Colors.surfaceContainerHigh

                Rectangle {
                    width: parent.width * Math.min(1, root.muted ? 0 : root.level)
                    height: parent.height
                    radius: 3
                    color: root.muted ? Colors.error : Colors.primary
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            Txt {
                id: pct
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "mute" : Math.round(root.level * 100) + "%"
                font.pixelSize: 12
                color: Colors.surfaceVariantOn
            }
        }
    }
}
