import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.theme
import "CalendarMath.js" as Cal

// Month grid with ISO week numbers and month stepping, opened from the clock.
// Closes on Esc, on a click anywhere outside the card, or after
// Style.popupIdleMs without use. The overlay starts below the bar, so the bar
// (including the clock, which toggles this) stays clickable.
PanelWindow {
    id: popup

    property date month: new Date()
    property real centerX: 0

    visible: false
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: Style.barHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "qs-calendar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open(win, cx) {
        month = new Date();
        centerX = cx;
        if (win && win.screen) screen = win.screen;
        visible = true;
        idle.restart();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    function toggle(win, cx) {
        if (visible) visible = false;
        else open(win, cx);
    }

    function step(n) {
        month = new Date(month.getFullYear(), month.getMonth() + n, 1);
        idle.restart();
    }

    Timer {
        id: idle
        interval: Style.popupIdleMs
        running: popup.visible
        onTriggered: popup.visible = false
    }

    // Click outside the card closes.
    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible = false
    }

    // Esc closes. (Needs keyboard focus, which the overlay takes while open.)
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: popup.visible = false
    }

    Rectangle {
        id: card

        width: 292
        height: 262
        x: Math.max(Style.gap, Math.min(popup.centerX - width / 2, popup.width - width - Style.gap))
        y: 4
        radius: Style.radius
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Colors.outlineVariant

        // Wheel steps the month. Declared first so the controls above it still get clicks.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                popup.step(wheel.angleDelta.y > 0 ? -1 : 1);
                wheel.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Txt {
                    text: "\uf104"
                    font.pixelSize: 18
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea { anchors.fill: parent; onClicked: popup.step(-1) }
                }
                Txt {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    text: Qt.formatDate(popup.month, "MMMM yyyy")
                }
                Txt {
                    text: "\uf105"
                    font.pixelSize: 18
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    MouseArea { anchors.fill: parent; onClicked: popup.step(1) }
                }
            }

            GridLayout {
                columns: 8
                columnSpacing: 0
                rowSpacing: 2

                Repeater {
                    model: ["Wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    delegate: Txt {
                        required property string modelData
                        required property int index
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: index === 0 ? Colors.outline : Colors.surfaceVariantOn
                        font.pixelSize: 11
                    }
                }

                Repeater {
                    model: 48
                    delegate: Item {
                        id: cell

                        required property int index
                        readonly property int r: Math.floor(index / 8)
                        readonly property int c: index % 8
                        readonly property bool isWeek: c === 0
                        readonly property date d: Cal.cellDate(popup.month, r, Math.max(0, c - 1))
                        readonly property bool today: !isWeek && Cal.sameDay(d, new Date())
                        readonly property bool inMonth: d.getMonth() === popup.month.getMonth()

                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 26

                        Rectangle {
                            visible: cell.today
                            anchors.centerIn: parent
                            width: 26
                            height: 22
                            radius: 6
                            color: Colors.primary
                        }

                        Txt {
                            anchors.centerIn: parent
                            font.pixelSize: cell.isWeek ? 11 : Style.fontSize
                            font.bold: cell.today
                            text: cell.isWeek ? Cal.isoWeek(cell.d) : cell.d.getDate()
                            color: cell.today ? Colors.primaryOn
                                 : cell.isWeek ? Colors.outline
                                 : cell.inMonth ? Colors.surfaceOn
                                 : Colors.outline
                        }
                    }
                }
            }
        }
    }
}
