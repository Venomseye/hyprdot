import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Omarchy-style bar: a slim full-width slab, flat, monospace.
//   left    menu button, workspaces
//   centre  clock pinned to the exact centre, media flanking it
//   right   tray drawer, updates, night light, do-not-disturb, network, bluetooth,
//           microphone, audio, battery, quick settings
// Double-click empty bar space to toggle transparency.
PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Style.barHeight
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"

    // ---- tooltips: BarItem calls these on hover (see BarItem.qml)
    property string tipText: ""
    property real tipX: 0
    readonly property bool tipVisible: tipWin.visible

    function showTip(text, x) {
        tipText = text;
        tipX = x;
        tipWin.visible = true;
    }

    function hideTip() {
        tipWin.visible = false;
    }

    PanelWindow {
        id: tipWin

        visible: false
        screen: bar.screen
        anchors {
            top: true
            left: true
        }
        margins.top: Style.barHeight + 3
        // centred on the icon, but never past either screen edge
        margins.left: Math.max(Style.gap, Math.min(Math.round(bar.tipX - tipBox.width / 2), bar.width - tipBox.width - Style.gap))
        implicitWidth: tipBox.width
        implicitHeight: tipBox.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}          // never takes the pointer
        WlrLayershell.namespace: "qs-tooltip"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            id: tipBox
            width: tipLabel.width + 18
            height: tipLabel.height + 12
            radius: 7
            color: Colors.alpha(Colors.surfaceContainerHigh, 0.96)
            border.width: 1
            border.color: Colors.outlineVariant

            Txt {
                id: tipLabel
                anchors.centerIn: parent
                text: bar.tipText
                font.pixelSize: 13
                width: Math.min(implicitWidth, 320)
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // The slab. Declared first so widgets sit above its MouseArea.
    Rectangle {
        anchors.fill: parent
        color: ShellState.barTransparent ? "transparent" : Colors.surface
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Colors.outlineVariant
            visible: !ShellState.barTransparent
        }

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: ShellState.barTransparent = !ShellState.barTransparent
        }
    }

    RowLayout {
        id: leftGroup
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        MenuButton {}
        Workspaces {}
    }

    Clock {
        id: clock
        anchors.centerIn: parent
    }

    Media {
        // the room between the workspaces and the clock; the pill shortens its text to fit
        maxWidth: Math.max(0, clock.x - Style.gap - (leftGroup.x + leftGroup.width) - Style.gap)
        anchors.right: clock.left
        anchors.rightMargin: Style.gap
        anchors.verticalCenter: parent.verticalCenter
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Tray {}
        UpdatesItem {}
        NightLightItem {}
        Indicators {}
        Network {}
        Bluetooth {}
        MicItem {}
        Audio {}
        Power {}
        QuickItem {}
    }
}
