import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import qs.theme
import qs.services
import "Fuzzy.js" as Fuzzy

// One searchable, nested menu for apps and commands (Super+Space).
//   type          fuzzy/acronym search across apps AND every command
//   Up/Down/Enter move and run; Enter on a category opens it
//   Backspace     on an empty field: back up a level
//   Esc           close the menu (so does clicking outside, or 30s without activity)
//   Anything with "confirm": true (power actions) asks for a second Enter
// Commands come from menu.json (shipped) and ~/.config/quickshell/menu.user.json
// (yours, appended to the top level). Same format: title, glyph, subtitle,
// then either `action` (a shell command) or `children`.
PanelWindow {
    id: root

    property var base: []
    property var extra: []
    property var path: []          // categories entered so far
    property string query: ""
    property var pending: null          // node waiting for a second Enter (confirm)
    property int selected: 0
    property int viewStart: 0           // first visible row; the list scrolls
    readonly property int pageSize: 9

    readonly property bool shown: ShellState.menuOpen
    property var generated: []          // Snippets / Emoji from dot-snippets
    readonly property var tree: base.concat(generated).concat(extra)
    readonly property var level: path.length > 0 ? path[path.length - 1].children : tree
    readonly property var rows: buildRows(query, level, path)
    readonly property var visibleRows: rows.slice(viewStart, viewStart + pageSize)

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
    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---- data ---------------------------------------------------------------

    function parse(text) {
        try {
            const v = JSON.parse(text);
            return Array.isArray(v) ? v : [];
        } catch (e) {
            console.warn("menu: invalid JSON: " + e);
            return [];
        }
    }

    function buildRows(q, nodes, trail) {
        const term = q.trim().toLowerCase();

        if (term === "") {
            return nodes.map(n => ({
                title: n.title,
                subtitle: n.subtitle || "",
                glyph: n.glyph || "",
                node: n,
                action: n.action || "",
                children: n.children !== undefined,
                score: 0
            })).slice(0, 60);
        }

        const out = Fuzzy.search(term, nodes, trail.map(t => t.title));

        // Apps are searched from the top level only.
        if (trail.length === 0) {
            for (const a of DesktopEntries.applications.values) {
                if (a.noDisplay) continue;
                const s = Fuzzy.best(term, [a.name, a.genericName, a.comment]);
                if (s > 0) {
                    out.push({
                        title: a.name,
                        subtitle: a.genericName || a.comment || "Application",
                        icon: a.icon,
                        entry: a,
                        children: false,
                        score: s + 5      // apps edge out equal-scoring commands
                    });
                }
            }
        }

        out.sort((x, y) => (y.score - x.score) || x.title.localeCompare(y.title));
        return out.slice(0, 60);
    }

    // ---- actions ------------------------------------------------------------

    // Runs a menu command. ~/.local/bin is put on PATH first (dot-reload and friends
    // live there). With `report` the command's output (or failure) comes back as a
    // notification - commands run with no terminal, so silence looks like "broken".
    function execAction(action, title, report) {
        if (!action) return;
        const bin = action.trim().split(/\s+/)[0];
        const check = 'PATH="$HOME/.local/bin:$PATH"; export PATH; ' +
            'if ! command -v "$1" >/dev/null 2>&1; then ' +
            'command -v notify-send >/dev/null 2>&1 && notify-send -u critical "$3" "$1 is not installed (run install.sh)"; exit 127; fi; ';
        const body = report
            ? 'out="$(eval "$2" 2>&1)"; rc=$?; msg="$(printf "%s" "$out" | tail -n 4)"; ' +
              'if [ $rc -eq 0 ]; then notify-send -a menu "$3" "${msg:-Done}"; ' +
              'else notify-send -u critical -a menu "$3 failed" "${msg:-exit code $rc}"; fi'
            : 'eval "$2"';
        Quickshell.execDetached(["sh", "-c", check + body, "sh", bin, action, title || "Menu"]);
    }

    function run(row) {
        if (!row) return;
        if (row.children) {
            path = path.concat([row.node]);
            clearQuery();
            return;
        }
        // Destructive entries need a second Enter.
        if (row.node && row.node.confirm && pending !== row.node) {
            pending = row.node;
            idle.restart();
            return;
        }
        pending = null;
        ShellState.menuOpen = false;
        if (row.entry) row.entry.execute();
        else execAction(row.action, row.title, row.node && row.node.notify === true);
    }

    // Move the highlight; the window of visible rows follows it.
    function select(i) {
        if (rows.length === 0) return;
        selected = Math.max(0, Math.min(i, rows.length - 1));
        pending = null;
        idle.restart();
        if (selected < viewStart) viewStart = selected;
        else if (selected >= viewStart + pageSize) viewStart = selected - pageSize + 1;
    }

    onRowsChanged: {
        selected = 0;
        viewStart = 0;
        pending = null;
        idle.restart();
    }

    // Closes itself after Style.menuIdleMs without a key press or mouse move.
    Timer {
        id: idle
        interval: Style.menuIdleMs
        running: root.shown
        onTriggered: ShellState.menuOpen = false
    }

    function clearQuery() {
        field.text = "";
        query = "";
        selected = 0;
        viewStart = 0;
    }

    function back() {
        if (query !== "") { clearQuery(); return; }
        if (path.length > 0) { path = path.slice(0, -1); selected = 0; viewStart = 0; return; }
        ShellState.menuOpen = false;
    }

    // Enter the category named by ShellState.menuCategory, if any (Super+Shift+P -> System).
    function enterRequestedCategory() {
        const want = ShellState.menuCategory;
        if (want === "") return;
        const node = tree.find(n => n.children && n.title.toLowerCase() === want.toLowerCase());
        if (node) path = [node];
    }

    onShownChanged: {
        if (shown) {
            if (!userMenu.running) userMenu.running = true;
            if (!snippets.running) snippets.running = true;
            pending = null;
            path = [];
            enterRequestedCategory();
            clearQuery();
            Qt.callLater(() => field.forceActiveFocus());
        }
    }

    FileView {
        path: Quickshell.shellPath("menu/menu.json")
        onLoaded: root.base = root.parse(text())
        onLoadFailed: error => console.warn("menu.json: " + error)
    }

    // Text/emoji snippets, generated from ~/.config/xcompose/vars by dot-snippets.
    Process {
        id: snippets
        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; command -v dot-snippets >/dev/null 2>&1 && dot-snippets --menu || echo "[]"']
        stdout: StdioCollector {
            onStreamFinished: root.generated = root.parse(this.text)
        }
    }

    // Your own entries. Read each time the menu opens; a missing file is fine.
    Process {
        id: userMenu
        command: ["sh", "-c", 'cat "$1" 2>/dev/null || echo "[]"', "sh", Style.configHome + "/quickshell/menu.user.json"]
        stdout: StdioCollector {
            onStreamFinished: root.extra = root.parse(this.text)
        }
    }

    // ---- view ---------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.35

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.menuOpen = false
        }
    }

    Rectangle {
        id: card

        readonly property int rowHeight: 40

        width: Math.min(720, Math.max(480, parent.width * 0.4))
        height: content.implicitHeight + 24
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.2)
        radius: Style.menuRadius
        color: Colors.surface
        border.width: 1
        border.color: Colors.outlineVariant

        MouseArea { anchors.fill: parent }   // swallow clicks on the card

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // breadcrumb
            Txt {
                visible: root.path.length > 0
                text: "\uf104  " + root.path.map(p => p.title).join(" \u203a ")
                color: Colors.surfaceVariantOn
                font.pixelSize: 12
                Layout.leftMargin: 4
            }

            TextField {
                id: field

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                leftPadding: 14
                placeholderText: root.path.length > 0 ? "Filter " + root.path[root.path.length - 1].title + "..." : "Search apps and commands..."
                placeholderTextColor: Colors.surfaceVariantOn
                color: Colors.surfaceOn
                selectionColor: Colors.primary
                selectedTextColor: Colors.primaryOn
                font.family: Style.fontFamily
                font.pixelSize: 15
                background: Rectangle {
                    radius: 8
                    color: Colors.surfaceContainer
                }

                onTextChanged: root.query = text
                onAccepted: root.run(root.rows[root.selected])

                Keys.onDownPressed: root.select(root.selected + 1)
                Keys.onUpPressed: root.select(root.selected - 1)
                Keys.onEscapePressed: {
                    if (root.pending !== null) root.pending = null;
                    else ShellState.menuOpen = false;
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace && text === "" && root.path.length > 0) {
                        root.back();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        root.select((root.selected + 1) % Math.max(1, root.rows.length));
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        root.select(root.selected + root.pageSize);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        root.select(root.selected - root.pageSize);
                        event.accepted = true;
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(root.rows.length, root.pageSize) * card.rowHeight
                visible: root.rows.length > 0

                // Wheel scrolls the selection. The rows' own MouseAreas have no
                // onWheel, so wheel events fall through to this one.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        root.select(root.selected + (wheel.angleDelta.y > 0 ? -1 : 1));
                        wheel.accepted = true;
                    }
                }

                Column {
                    anchors.fill: parent

                    Repeater {
                        model: root.visibleRows

                        delegate: Rectangle {
                            id: item

                            required property var modelData
                            required property int index
                            readonly property int rowIndex: root.viewStart + index
                            readonly property bool active: rowIndex === root.selected

                            width: parent.width
                            height: card.rowHeight
                            radius: 8
                            color: active ? Colors.primaryContainer : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 12

                                Item {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24

                                    IconImage {
                                        anchors.fill: parent
                                        visible: !!item.modelData.icon
                                        source: item.modelData.icon ? Quickshell.iconPath(item.modelData.icon, "application-x-executable") : ""
                                    }
                                    Txt {
                                        anchors.centerIn: parent
                                        visible: !item.modelData.icon
                                        text: item.modelData.glyph || "\uf105"
                                        color: item.active ? Colors.primaryContainerOn : Colors.primary
                                        font.pixelSize: 16
                                    }
                                }

                                Txt {
                                    Layout.fillWidth: true
                                    text: item.modelData.title
                                    elide: Text.ElideRight
                                    color: item.active ? Colors.primaryContainerOn : Colors.surfaceOn
                                }

                                Txt {
                                    readonly property bool asking: root.pending !== null && root.pending === item.modelData.node
                                    text: asking ? "Press Enter again to confirm" : item.modelData.subtitle
                                    visible: text !== ""
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: card.width * 0.45
                                    color: asking ? Colors.error : (item.active ? Colors.primaryContainerOn : Colors.surfaceVariantOn)
                                    font.bold: asking
                                    font.pixelSize: 12
                                }

                                Txt {
                                    visible: item.modelData.children
                                    text: "\uf105"
                                    color: item.active ? Colors.primaryContainerOn : Colors.surfaceVariantOn
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.select(item.rowIndex)
                                onClicked: root.run(item.modelData)
                            }
                        }
                    }
                }
            }

            Txt {
                visible: root.rows.length > root.pageSize
                text: (root.selected + 1) + " / " + root.rows.length + "   (scroll, PageUp/PageDown)"
                color: Colors.surfaceVariantOn
                font.pixelSize: 11
                Layout.leftMargin: 6
            }

            Txt {
                visible: root.rows.length === 0
                text: "No matches"
                color: Colors.surfaceVariantOn
                Layout.leftMargin: 6
                Layout.bottomMargin: 6
            }
        }
    }
}
