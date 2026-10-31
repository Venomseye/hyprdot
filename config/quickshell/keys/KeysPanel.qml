import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services

// Keybinds (Super+/, or menu -> Keybinds): every shortcut as a tile, grouped by what it does,
// with real key caps. The list is read from hypr/bindings.lua by `dot-keys --json`, so it is
// always what is actually bound. Type to filter; Esc clears the filter, then closes (so does a
// click outside).
PanelWindow {
    id: root

    readonly property bool shown: ShellState.keysOpen

    property var all: []                 // [{cat, keys: [..], desc}]
    property string filter: ""
    property string error: ""
    readonly property var groups: {
        const q = filter.trim().toLowerCase();
        const order = [];
        const map = {};
        for (const t of all) {
            if (q !== "" && !(t.desc.toLowerCase().includes(q) || t.cat.toLowerCase().includes(q) || t.keys.join(" ").toLowerCase().includes(q)))
                continue;
            if (!map[t.cat]) { map[t.cat] = []; order.push(t.cat); }
            map[t.cat].push(t);
        }
        return order.map(c => ({ cat: c, items: map[c] }));
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: shown || card.opacity > 0.01
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "qs-keys"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!shown) return;
        filter = "";
        field.text = "";
        if (!loader.running) loader.running = true;      // cheap, and always current
        Qt.callLater(() => field.forceActiveFocus());
    }

    Process {
        id: loader
        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; command -v dot-keys >/dev/null 2>&1 && dot-keys --json || echo "NOKEYS"']
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (text === "NOKEYS" || text === "") {
                    root.error = "dot-keys is not installed (run install.sh; it needs python)";
                    return;
                }
                try {
                    root.all = JSON.parse(text);
                    root.error = "";
                } catch (e) {
                    root.error = "could not read the keybind list: " + e;
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: root.shown ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: root.shown ? Style.animMs : Style.animOutMs } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.keysOpen = false
    }

    Rectangle {
        id: card

        property real slide: root.shown ? 0 : 12
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.shown ? Style.animMs : Style.animOutMs; easing.type: Easing.OutQuint } }
        Behavior on slide { NumberAnimation { duration: root.shown ? Style.animMs : Style.animOutMs; easing.type: Easing.OutQuint } }

        readonly property int cols: width >= 900 ? 3 : 2
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2) + slide
        width: Math.min(960, parent.width - 4 * Style.gap)
        height: Math.min(680, parent.height - 6 * Style.gap)
        radius: Style.menuRadius
        color: Colors.alpha(Colors.surface, Style.panelOpacity)
        border.width: 1
        border.color: Colors.outlineVariant

        MouseArea { anchors.fill: parent }       // swallow clicks on the card

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Txt {
                    text: "\uf11c"
                    font.pixelSize: 18
                    color: Colors.primary
                }
                Txt {
                    text: "Keybinds"
                    font.pixelSize: 16
                    font.bold: true
                }
                Txt {
                    text: root.filter === "" ? root.all.length + " shortcuts" : root.groups.reduce((n, g) => n + g.items.length, 0) + " found"
                    font.pixelSize: 12
                    color: Colors.surfaceVariantOn
                }
                Item { Layout.fillWidth: true }

                TextField {
                    id: field
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 34
                    leftPadding: 12
                    placeholderText: "Filter..."
                    placeholderTextColor: Colors.surfaceVariantOn
                    color: Colors.surfaceOn
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.primaryOn
                    font.family: Style.fontFamily
                    font.pixelSize: 13
                    background: Rectangle {
                        radius: 8
                        color: Colors.surfaceContainer
                        border.width: field.activeFocus ? 1 : 0
                        border.color: Colors.primary
                    }
                    onTextChanged: root.filter = text
                    Keys.onEscapePressed: {
                        if (text !== "") text = "";
                        else ShellState.keysOpen = false;
                    }
                }
            }

            Txt {
                visible: root.error !== ""
                text: root.error
                color: Colors.error
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Txt {
                visible: root.error === "" && root.all.length > 0 && root.groups.length === 0
                text: "No shortcut matches \"" + root.filter + "\""
                color: Colors.surfaceVariantOn
                Layout.alignment: Qt.AlignHCenter
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body
                    width: flick.width - 6
                    spacing: 16

                    Repeater {
                        model: root.groups

                        ColumnLayout {
                            id: section
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            Txt {
                                text: section.modelData.cat.toUpperCase()
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1.2
                                color: Colors.primary
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: section.modelData.items

                                    Rectangle {
                                        id: tile
                                        required property var modelData
                                        width: Math.floor((body.width - 8 * (card.cols - 1)) / card.cols)
                                        height: 62
                                        radius: 10
                                        color: tileHover.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        HoverHandler { id: tileHover }

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 7

                                            Txt {
                                                width: parent.width
                                                text: tile.modelData.desc
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                spacing: 4

                                                Repeater {
                                                    model: tile.modelData.keys

                                                    Rectangle {
                                                        id: cap
                                                        required property var modelData
                                                        height: 22
                                                        width: Math.max(22, capLabel.implicitWidth + 14)
                                                        radius: 6
                                                        color: Colors.surfaceContainerHighest
                                                        border.width: 1
                                                        border.color: Colors.outlineVariant

                                                        Txt {
                                                            id: capLabel
                                                            anchors.centerIn: parent
                                                            text: cap.modelData
                                                            font.pixelSize: 12
                                                            color: Colors.surfaceOn
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
