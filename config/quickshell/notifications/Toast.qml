import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.theme

// One notification banner. Click anywhere = dismiss. Hover pauses the timeout.
// Critical ones get an error-coloured border and stay a little longer.
Rectangle {
    id: toast

    property var notif

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property bool hasImage: (notif.image ?? "") !== ""
    // Theme icon only if it really exists (iconPath(name, true) gives "" when it
    // doesn't); otherwise a bell glyph instead of the purple missing-icon tile.
    readonly property string iconSource: {
        if (hasImage) return notif.image;
        const name = notif.appIcon ?? "";
        return name !== "" ? (Quickshell.iconPath(name, true) || "") : "";
    }

    implicitHeight: Math.max(36, textCol.implicitHeight) + 24
    radius: Style.radius
    color: Colors.surfaceContainer
    border.width: critical ? 2 : 1
    border.color: critical ? Colors.error : Colors.outlineVariant

    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: 150 } }

    HoverHandler { id: hover }

    // Every notification times out - critical ones just stay longer. Hovering pauses it,
    // clicking dismisses. An explicit timeout from the sender wins.
    Timer {
        running: !hover.hovered
        interval: toast.notif.expireTimeout > 0 ? toast.notif.expireTimeout * 1000
                : toast.critical ? Style.toastCriticalMs : Style.toastMs
        onTriggered: toast.notif.expire()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toast.notif.dismiss()
    }

    IconImage {
        id: icon
        x: 12
        y: 12
        implicitSize: 36
        visible: toast.iconSource !== ""
        source: toast.iconSource
    }

    Rectangle {
        x: 12
        y: 12
        width: 36
        height: 36
        radius: 8
        visible: toast.iconSource === ""
        color: Colors.primaryContainer

        Txt {
            anchors.centerIn: parent
            text: "\uf0f3"
            color: Colors.primaryContainerOn
            font.pixelSize: 16
        }
    }

    Column {
        id: textCol
        x: 60
        y: 12
        width: toast.width - 60 - 28
        spacing: 3

        Txt {
            width: parent.width
            text: toast.notif.appName
            color: Colors.surfaceVariantOn
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Txt {
            width: parent.width
            text: toast.notif.summary
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Txt {
            width: parent.width
            visible: text !== ""
            text: toast.notif.body
            textFormat: Text.StyledText
            color: Colors.surfaceVariantOn
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
        Flow {
            width: parent.width
            spacing: 6
            visible: toast.notif.actions.length > 0

            Repeater {
                model: toast.notif.actions

                delegate: Rectangle {
                    required property var modelData
                    width: label.implicitWidth + 16
                    height: 24
                    radius: 6
                    color: Colors.primaryContainer

                    Txt {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        color: Colors.primaryContainerOn
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.modelData.invoke()
                    }
                }
            }
        }
    }

    Txt {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        text: "\uf00d"
        color: Colors.surfaceVariantOn
        font.pixelSize: 11
    }
}
