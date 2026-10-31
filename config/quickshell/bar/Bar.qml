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
    // The three looks (ShellState.barStyle). classic = the flat full-width slab; floating and
    // islands are inset from the screen edge and rounded.
    readonly property bool floating: ShellState.barStyle !== "classic"
    readonly property bool islands: ShellState.barStyle === "islands"
    readonly property int sideInset: floating ? Style.gap : 0
    margins {
        top: bar.floating ? ShellState.barInset : 0
        left: bar.sideInset
        right: bar.sideInset
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Style.barHeight
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
        margins.top: Style.barHeight + ShellState.barInset + 3
        // centred on the icon, but never past either screen edge
        margins.left: Math.max(Style.gap, Math.min(Math.round(bar.tipX - tipBox.width / 2) + bar.sideInset, bar.width + 2 * bar.sideInset - tipBox.width - Style.gap))
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

    // The background. Declared first so widgets sit above it.
    // classic: flat slab. floating: one rounded bar. islands: no slab, see the Repeater below.
    Rectangle {
        anchors.fill: parent
        visible: !bar.islands
        radius: bar.floating ? Style.radius : 0
        color: ShellState.barTransparent ? "transparent"
             : (bar.floating ? Colors.alpha(Colors.surface, 0.94) : Colors.surface)
        border.width: (bar.floating && !ShellState.barTransparent) ? 1 : 0
        border.color: Colors.outlineVariant
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Colors.outlineVariant
            visible: !ShellState.barTransparent && !bar.floating
        }
    }

    // islands: a rounded pill behind each of the left group, the clock and the right group
    Repeater {
        model: bar.islands ? [leftGroup, clock, rightGroup] : []
        Rectangle {
            required property var modelData
            x: modelData.x - 8
            width: modelData.width + 16
            height: parent.height
            radius: Style.radius
            color: ShellState.barTransparent ? "transparent" : Colors.alpha(Colors.surface, 0.94)
            border.width: ShellState.barTransparent ? 0 : 1
            border.color: Colors.outlineVariant
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onDoubleClicked: ShellState.barTransparent = !ShellState.barTransparent
    }

    RowLayout {
        id: leftGroup
        anchors.left: parent.left
        anchors.leftMargin: bar.islands ? 10 : 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        MenuButton {}
        Workspaces {}
    }

    Clock {
        id: clock
        anchors.centerIn: parent
    }

    RowLayout {
        id: rightGroup
        anchors.right: parent.right
        anchors.rightMargin: bar.islands ? 10 : 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Media {}
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
