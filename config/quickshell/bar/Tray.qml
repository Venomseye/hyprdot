import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme

// Tray drawer: only a chevron until you hover it, then the icons slide out.
// left = activate, middle = secondary activate, right = the item's menu.
Item {
    id: root

    property bool revealed: false

    visible: SystemTray.items.values.length > 0
    implicitWidth: row.implicitWidth + 12
    implicitHeight: Style.barHeight

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                collapse.stop();
                root.revealed = true;
            } else {
                collapse.restart();
            }
        }
    }

    Timer {
        id: collapse
        interval: 700
        onTriggered: root.revealed = hover.hovered
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: SystemTray.items

            delegate: IconImage {
                id: icon

                required property var modelData

                visible: root.revealed
                implicitSize: 16
                source: modelData.icon

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            icon.modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            icon.modelData.secondaryActivate();
                        } else if (icon.modelData.hasMenu) {
                            const p = icon.mapToItem(null, 0, icon.height + 4);
                            icon.modelData.display(icon.QsWindow.window, p.x, p.y);
                        }
                    }
                }
            }
        }

        Txt {
            text: root.revealed ? "\uf105" : "\uf104"
            color: Colors.surfaceVariantOn
        }
    }
}
