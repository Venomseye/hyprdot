import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.theme
import qs.services

// Notification daemon + banners (replaces mako).
//   * Do Not Disturb (qs ipc call shell toggle dnd): banners are suppressed
//     except critical ones; everything is still recorded in the history.
//   * Duplicate suppression: an identical notification already on screen is
//     dropped instead of stacked.
//   * History: the last ten, shown by `qs ipc call shell toggle history`.
// Only one notification daemon can own org.freedesktop.Notifications - stop
// mako/dunst before starting this.
Scope {
    id: root

    property var history: []      // newest first, max 10
    readonly property int maxVisible: 4

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: n => root.handle(n)
    }

    function handle(n) {
        const entry = { appName: n.appName, summary: n.summary, body: n.body, time: new Date() };
        const h = history.slice();
        h.unshift(entry);
        history = h.slice(0, 10);

        const critical = n.urgency === NotificationUrgency.Critical;
        if (ShellState.dnd && !critical) return;     // never tracked = never shown

        const dup = server.trackedNotifications.values.some(t =>
            t.appName === n.appName && t.summary === n.summary && t.body === n.body);
        if (dup) return;

        n.tracked = true;
    }

    // ---- banners (top right, under the bar) ---------------------------------
    PanelWindow {
        visible: server.trackedNotifications.values.length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: Style.barHeight + Style.gap
            right: Style.gap
        }
        implicitWidth: 400
        implicitHeight: stack.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "qs-notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        ColumnLayout {
            id: stack
            width: parent.width
            spacing: Style.gap

            Repeater {
                model: server.trackedNotifications

                delegate: Toast {
                    required property var modelData
                    required property int index

                    notif: modelData
                    Layout.fillWidth: true
                    visible: index >= server.trackedNotifications.values.length - root.maxVisible
                }
            }
        }
    }

    // ---- history ------------------------------------------------------------
    PanelWindow {
        id: historyWin

        visible: ShellState.historyOpen
        // Full-screen below the bar so a click outside the panel closes it, and so it can
        // take the keyboard for Esc. Also closes itself after Style.popupIdleMs.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: Style.barHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "qs-notification-history"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) {
            idle.restart();
            Qt.callLater(() => keys.forceActiveFocus());
        }

        Timer {
            id: idle
            interval: Style.popupIdleMs
            running: historyWin.visible
            onTriggered: ShellState.historyOpen = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.historyOpen = false
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: ShellState.historyOpen = false
        }

        Rectangle {
            id: panel
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Style.gap
            anchors.rightMargin: Style.gap
            width: 400
            implicitHeight: list.implicitHeight + 24
            height: implicitHeight
            radius: Style.radius
            color: Colors.surfaceContainer
            border.width: 1
            border.color: Colors.outlineVariant

            MouseArea {
                anchors.fill: parent
                onClicked: ShellState.historyOpen = false
            }

            Column {
                id: list
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 10

                Txt {
                    text: "Notification history" + (ShellState.dnd ? "  (Do Not Disturb)" : "")
                    font.bold: true
                }

                Txt {
                    visible: root.history.length === 0
                    text: "Nothing yet"
                    color: Colors.surfaceVariantOn
                }

                Repeater {
                    model: root.history

                    delegate: Column {
                        required property var modelData
                        width: list.width
                        spacing: 1

                        Txt {
                            width: parent.width
                            text: Qt.formatDateTime(parent.modelData.time, "HH:mm") + "  " + parent.modelData.appName
                            color: Colors.surfaceVariantOn
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Txt {
                            width: parent.width
                            text: parent.modelData.summary
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: parent.modelData.body
                            textFormat: Text.StyledText
                            color: Colors.surfaceVariantOn
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
