import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services

// Wallpaper picker (Super+Shift+W): thumbnails of every image wpaperd can show.
//   arrows move, Enter or a click applies; just type to filter by name; Esc clears the
//   filter, then closes (so does a click outside, or Style.panelIdleMs after the pointer
//   leaves). "Random" applies a random one.
//   Dark/Light and Style change the colour scheme matugen derives from the wallpaper
//   "Rotate all" resumes the random rotation after you pinned one image
// Hover only selects once the mouse really moves, same as the menu.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.wallpapersOpen
    readonly property var styles: ["tonal-spot", "expressive", "fidelity", "content", "neutral", "monochrome", "rainbow", "fruit-salad"]

    property var images: []
    property string current: ""
    property bool rotating: true
    property string mode: "dark"
    property string style: "tonal-spot"
    property int index: 0
    property string filter: ""
    property real lastX: -1
    property real lastY: -1

    readonly property var shownImages: filter === "" ? images : images.filter(p => baseName(p).toLowerCase().includes(filter))
    readonly property string selectedPath: shownImages[index] ?? ""
    readonly property int cols: Math.max(2, Math.floor((card.width - 28) / 220))

    function baseName(p) {
        const f = p.split("/").pop();
        const dot = f.lastIndexOf(".");
        return dot > 0 ? f.slice(0, dot) : f;
    }

    function fileUrl(p) {
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    function parseState(text) {
        for (const line of text.split("\n")) {
            const eq = line.indexOf("=");
            if (eq < 0) continue;
            const k = line.slice(0, eq), v = line.slice(eq + 1);
            if (k === "current") current = v;
            else if (k === "rotating") rotating = v === "yes";
            else if (k === "mode") mode = v;
            else if (k === "style") style = v;
        }
        const at = shownImages.indexOf(current);
        if (at >= 0) index = at;
    }

    function move(i) {
        if (shownImages.length === 0) return;
        index = Math.max(0, Math.min(shownImages.length - 1, i));
        grid.positionViewAtIndex(index, GridView.Contain);
    }

    function setFilter(text) {
        filter = text;
        index = 0;
        grid.positionViewAtBeginning();
    }

    function applyRandom() {
        const pool = shownImages.filter(p => p !== current);
        if (pool.length === 0) return;
        apply(pool[Math.floor(Math.random() * pool.length)]);
    }

    function apply(path) {
        if (!path) return;
        ShellState.wallpapersOpen = false;
        Run.report('dot-wallpaper set "$1"', [path], "Wallpaper");
    }

    function setMode(m) {
        if (m === mode) return;
        mode = m;
        Run.report('dot-wallpaper theme mode "$1"', [m], "Theme");
    }

    function nextStyle() {
        const next = styles[(styles.indexOf(style) + 1) % styles.length];
        style = next;
        Run.report('dot-wallpaper theme style "$1"', [next], "Theme");
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "qs-wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!shown) return;
        lastX = -1;
        lastY = -1;
        filter = "";
        if (!listProc.running) listProc.running = true;
        if (!stateProc.running) stateProc.running = true;
        appear.restart();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    Process {
        id: listProc
        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; command -v dot-wallpaper >/dev/null 2>&1 && dot-wallpaper list']
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = this.text.split("\n").filter(l => l !== "");
                const at = root.shownImages.indexOf(root.current);
                root.index = at >= 0 ? at : 0;
            }
        }
    }

    Process {
        id: stateProc
        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; command -v dot-wallpaper >/dev/null 2>&1 && dot-wallpaper state']
        stdout: StdioCollector {
            onStreamFinished: root.parseState(this.text)
        }
    }

    Timer {
        interval: Style.panelIdleMs
        running: root.shown && !hover.hovered
        onTriggered: ShellState.wallpapersOpen = false
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: root.shown ? 0.4 : 0
        Behavior on opacity { NumberAnimation { duration: Style.animMs } }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.wallpapersOpen = false
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.filter !== "") root.setFilter("");
                else ShellState.wallpapersOpen = false;
            }
            else if (event.key === Qt.Key_Left) root.move(root.index - 1);
            else if (event.key === Qt.Key_Right) root.move(root.index + 1);
            else if (event.key === Qt.Key_Up) root.move(root.index - root.cols);
            else if (event.key === Qt.Key_Down) root.move(root.index + root.cols);
            else if (event.key === Qt.Key_PageUp) root.move(root.index - root.cols * 3);
            else if (event.key === Qt.Key_PageDown) root.move(root.index + root.cols * 3);
            else if (event.key === Qt.Key_Home) root.move(0);
            else if (event.key === Qt.Key_End) root.move(root.shownImages.length - 1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.apply(root.selectedPath);
            else if (event.key === Qt.Key_Backspace) root.setFilter(root.filter.slice(0, -1));
            else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                root.setFilter(root.filter + event.text.toLowerCase());
            else return;
            event.accepted = true;
        }
    }

    ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Style.animMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "slide"; from: 16; to: 0; duration: Style.animMs; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card

        property real slide: 0
        width: Math.min(parent.width - 2 * Style.gap, Math.min(1040, Math.max(560, parent.width * 0.72)))
        height: Math.min(parent.height - 80, Math.max(360, parent.height * 0.72))
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2) + slide
        radius: Style.menuRadius
        color: Colors.alpha(Colors.surface, Style.panelOpacity)
        border.width: 1
        border.color: Colors.outlineVariant

        HoverHandler { id: hover }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ---- header: title, scheme controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Txt {
                    text: "Wallpapers"
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: root.filter !== ""
                    implicitWidth: filterLabel.implicitWidth + 20
                    implicitHeight: 26
                    radius: 13
                    color: Colors.secondaryContainer
                    Txt {
                        id: filterLabel
                        anchors.centerIn: parent
                        text: "\uf002  " + root.filter
                        font.pixelSize: 13
                        color: Colors.secondaryContainerOn
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.setFilter("")
                    }
                }

                Txt {
                    visible: !root.rotating
                    text: "pinned"
                    color: Colors.tertiary
                    font.pixelSize: 13
                }

                Rectangle {
                    implicitWidth: randLabel.implicitWidth + 24
                    implicitHeight: 28
                    radius: 8
                    color: Colors.surfaceContainerHigh
                    Txt {
                        id: randLabel
                        anchors.centerIn: parent
                        text: "\uf074  Random"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.applyRandom()
                    }
                }

                // Dark | Light
                Rectangle {
                    implicitWidth: 128
                    implicitHeight: 28
                    radius: 8
                    color: Colors.surfaceContainerHigh

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: ["dark", "light"]
                            delegate: Rectangle {
                                required property string modelData
                                width: parent.width / 2
                                height: parent.height
                                radius: 8
                                color: root.mode === modelData ? Colors.primary : "transparent"
                                Txt {
                                    anchors.centerIn: parent
                                    text: parent.modelData === "dark" ? "Dark" : "Light"
                                    font.pixelSize: 13
                                    color: root.mode === parent.modelData ? Colors.primaryOn : Colors.surfaceOn
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.setMode(parent.modelData)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    implicitWidth: styleLabel.implicitWidth + 24
                    implicitHeight: 28
                    radius: 8
                    color: Colors.surfaceContainerHigh
                    Txt {
                        id: styleLabel
                        anchors.centerIn: parent
                        text: "Style: " + root.style
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.nextStyle()
                    }
                }

                Rectangle {
                    visible: !root.rotating
                    implicitWidth: rotLabel.implicitWidth + 24
                    implicitHeight: 28
                    radius: 8
                    color: Colors.primaryContainer
                    Txt {
                        id: rotLabel
                        anchors.centerIn: parent
                        text: "Rotate all"
                        font.pixelSize: 13
                        color: Colors.primaryContainerOn
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            ShellState.wallpapersOpen = false;
                            Run.report("dot-wallpaper rotate", [], "Wallpaper");
                        }
                    }
                }

                Txt {
                    text: "\uf00d"
                    color: Colors.surfaceVariantOn
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: ShellState.wallpapersOpen = false
                    }
                }
            }

            // ---- thumbnails
            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.shownImages
                cellWidth: Math.floor(width / root.cols)
                cellHeight: Math.round(cellWidth * 0.64)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: cell

                    required property string modelData
                    required property int index
                    readonly property bool selected: index === root.index
                    readonly property bool isCurrent: modelData === root.current

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 10
                        color: Colors.surfaceContainerHigh
                        clip: true
                        // the selected one grows a little; easing keeps arrow-key movement smooth
                        scale: cell.selected ? 1.04 : 1.0
                        z: cell.selected ? 2 : 0
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        Image {
                            id: pic
                            anchors.fill: parent
                            source: root.fileUrl(cell.modelData)
                            sourceSize.width: 420
                            sourceSize.height: 270
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }

                        // name strip
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 24
                            color: Qt.rgba(0, 0, 0, 0.55)

                            Txt {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: root.baseName(cell.modelData)
                                color: "white"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        // current wallpaper marker
                        Rectangle {
                            visible: cell.isCurrent
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 22
                            height: 22
                            radius: 11
                            color: Colors.primary
                            Txt {
                                anchors.centerIn: parent
                                text: "\uf00c"
                                color: Colors.primaryOn
                                font.pixelSize: 12
                            }
                        }
                    }

                    // selection ring, drawn above the picture (grows with it)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 10
                        color: "transparent"
                        border.width: cell.selected ? 3 : 0
                        border.color: Colors.primary
                        scale: cell.selected ? 1.04 : 1.0
                        z: 3
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => {
                            const p = cell.mapToItem(null, mouse.x, mouse.y);
                            if (root.lastX < 0) { root.lastX = p.x; root.lastY = p.y; return; }
                            if (Math.abs(p.x - root.lastX) + Math.abs(p.y - root.lastY) < 3) return;
                            root.lastX = p.x;
                            root.lastY = p.y;
                            root.index = cell.index;
                        }
                        onClicked: root.apply(cell.modelData)
                    }
                }
            }

            Txt {
                visible: root.images.length === 0
                text: "No wallpapers found. Run  dot-wallpaper init  to create the config and add the bundled ones."
                color: Colors.surfaceVariantOn
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Txt {
                visible: root.images.length > 0 && root.shownImages.length === 0
                text: "Nothing matches \"" + root.filter + "\" - Backspace to edit, Esc to clear"
                color: Colors.surfaceVariantOn
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            // info bar: what is selected, how many, and the keys
            RowLayout {
                visible: root.shownImages.length > 0
                Layout.fillWidth: true
                spacing: 12

                Txt {
                    text: root.baseName(root.selectedPath)
                    font.bold: true
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Txt {
                    text: (root.index + 1) + " / " + root.shownImages.length
                    color: Colors.surfaceVariantOn
                    font.pixelSize: 13
                }
                Txt {
                    text: "arrows move   Enter apply   type to filter   Esc close"
                    color: Colors.surfaceVariantOn
                    font.pixelSize: 12
                }
            }
        }
    }
}
