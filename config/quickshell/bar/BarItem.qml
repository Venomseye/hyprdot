import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme

// Base for every bar widget: padded row, hover highlight, click + scroll.
Item {
    id: root

    default property alias content: row.data
    property bool interactive: true
    property bool showHover: true       // false = the widget draws its own hover state (the media pill)
    property int horizontalPadding: 8
    readonly property bool hovered: area.containsMouse
    property real scrollAcc: 0
    property string tooltip: ""      // shown under the item after hovering for a moment

    signal clicked(var mouse)
    signal scrolled(int delta)

    function hideTip() {
        tipTimer.stop();
        const w = root.QsWindow.window;
        if (w && w.hideTip) w.hideTip();
    }

    onHoveredChanged: {
        if (hovered && tooltip !== "") tipTimer.restart();
        else hideTip();
    }
    onTooltipChanged: {
        // keep an open tooltip current (volume changing while you scroll on it)
        const w = root.QsWindow.window;
        if (hovered && w && w.tipVisible && tooltip !== "") w.showTip(tooltip, root.mapToItem(null, root.width / 2, 0).x);
    }

    Timer {
        id: tipTimer
        interval: 450
        onTriggered: {
            const w = root.QsWindow.window;
            if (w && w.showTip && root.tooltip !== "") w.showTip(root.tooltip, root.mapToItem(null, root.width / 2, 0).x);
        }
    }

    // a click means "I know what this is" - hide the tooltip
    Connections {
        target: root
        function onClicked() { root.hideTip(); }
    }

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: Style.barHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        radius: 6
        color: root.interactive && root.showHover && root.hovered ? Colors.surfaceContainerHigh : "transparent"
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => root.clicked(mouse)

        // MouseArea.onWheel rather than WheelHandler: it is the long-standing,
        // reliable path on layer-shell windows. Emits scrolled(+-120) per step.
        onWheel: wheel => {
            const dy = wheel.angleDelta.y;
            if (Math.abs(dy) >= 120) {
                root.scrolled(dy > 0 ? 120 : -120);       // mouse wheel notch
                root.scrollAcc = 0;
            } else {
                root.scrollAcc += dy !== 0 ? dy : wheel.pixelDelta.y * 3;   // touchpad
                if (Math.abs(root.scrollAcc) >= 60) {
                    root.scrolled(root.scrollAcc > 0 ? 120 : -120);
                    root.scrollAcc = 0;
                }
            }
            wheel.accepted = true;
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
