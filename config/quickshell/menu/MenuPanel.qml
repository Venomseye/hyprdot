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
import "Calc.js" as Calc

// One searchable, nested menu for apps and commands (Super+Space).
//   type          fuzzy/acronym search across apps AND every command
//   Up/Down/Enter move and run; Enter on a category opens it
//   Esc           one step back: clears the search, then leaves the category you are in, then
//                 closes the menu at the top. (Opened straight into a category by a keybind,
//                 e.g. Super+Shift+P -> System, Esc closes.) Backspace on an empty field = back.
//                 Clicking outside, or 30s without activity, also closes.
//   mouse/keyboard  the highlight follows whichever you used last: hovering only selects
//                 once the mouse really MOVES, so a menu that opens under a resting
//                 pointer isn't hijacked
//   =2*(3+4)      calculator: Enter copies the result (also tried on plain 2*(3+4))
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
    property bool direct: false         // opened straight into a category by a keybind
    property var pending: null          // node waiting for a second Enter (confirm)
    property bool mouseMode: false      // true once the mouse moved after the last key press
    property real lastX: -1             // last real pointer position (scene coords)
    property real lastY: -1
    property int selected: 0
    property int viewStart: 0           // first visible row; the list scrolls
    readonly property int pageSize: 9

    readonly property bool shown: ShellState.menuOpen
    property var snipNodes: []          // Snippets / Emoji (dot-snippets)
    property var clipNodes: []          // Clipboard history (dot-clip)
    readonly property var generated: snipNodes.concat(clipNodes)
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

        // Calculator: "=..." is calculator-only; plain "12*(3+4)" adds a result row on top.
        const calcMode = term.startsWith("=");
        let calcRow = null;
        const expr = calcMode ? term.slice(1).trim() : term;
        if (expr !== "" && (calcMode || Calc.looksLikeMath(expr))) {
            const r = Calc.evaluate(expr);
            if (r.ok) {
                const shownValue = Calc.format(r.value);
                calcRow = { title: "= " + shownValue, subtitle: "Enter copies the result", glyph: "\uf1ec",
                            calc: shownValue, children: false, score: 1000 };
            }
        }
        if (calcMode) {
            return [calcRow ? calcRow : {
                title: expr === "" ? "Type a calculation" : "Can't calculate that",
                subtitle: "e.g.  2*(3+4)   sqrt(81)   2^10   100/8   pi*5^2",
                glyph: "\uf1ec", hint: true, children: false, score: 0
            }];
        }

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
        if (calcRow) out.unshift(calcRow);
        return out.slice(0, 60);
    }

    // ---- actions ------------------------------------------------------------

    function execAction(action, title, report) {
        Run.exec(action, title, report);
    }

    function run(row) {
        if (!row || row.hint) return;
        if (row.calc !== undefined) {
            ShellState.menuOpen = false;
            Run.sh('printf %s "$1" | wl-copy && notify-send -a calculator "Copied" "$1"', [row.calc]);
            return;
        }
        if (row.children) {
            path = path.concat([row.node]);
            clearQuery();
            return;
        }
        // Destructive entries need a second Enter.
        if (row.node && row.node.confirm && Style.confirmPower && pending !== row.node) {
            pending = row.node;
            idle.restart();
            return;
        }
        pending = null;
        ShellState.menuOpen = false;
        if (row.entry) row.entry.execute();
        else execAction(row.action, row.title, row.node && row.node.notify === true);
    }

    // Keyboard navigation: also hands control back from the mouse.
    function keySelect(i) {
        mouseMode = false;
        select(i);
    }

    // Move the highlight; the window of visible rows follows it.
    function select(i) {
        if (rows.length === 0) return;
        const next = Math.max(0, Math.min(i, rows.length - 1));
        // Moving to a DIFFERENT row cancels a pending "press Enter again". Hovering the row that is
        // already selected must not: a resting hand nudging the mouse made every confirm start over.
        if (next !== selected) pending = null;
        selected = next;
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
        if (path.length > (direct ? 1 : 0)) { path = path.slice(0, -1); selected = 0; viewStart = 0; return; }
        ShellState.menuOpen = false;
    }

    // Enter the category named by ShellState.menuCategory, if any (Super+Shift+P -> System).
    function enterRequestedCategory() {
        const want = ShellState.menuCategory;
        if (want === "") return;
        const node = tree.find(n => n.children && n.title.toLowerCase() === want.toLowerCase());
        if (node) {
            path = [node];
            direct = true;
        }
    }

    onShownChanged: {
        if (shown) {
            if (!userMenu.running) userMenu.running = true;
            if (!snippets.running) snippets.running = true;
            if (!clipProc.running) clipProc.running = true;
            pending = null;
            direct = false;
            mouseMode = false;
            lastX = -1;
            lastY = -1;
            path = [];
            enterRequestedCategory();
            clearQuery();
            if (ShellState.menuQuery !== "") {
                field.text = ShellState.menuQuery;
                ShellState.menuQuery = "";
            }
            appear.restart();
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
            onStreamFinished: root.snipNodes = root.parse(this.text)
        }
    }

    // Clipboard history (cliphist), Super+V.
    Process {
        id: clipProc
        command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH"; command -v dot-clip >/dev/null 2>&1 && dot-clip --menu || echo "[]"']
        stdout: StdioCollector {
            onStreamFinished: root.clipNodes = root.parse(this.text)
        }
    }

    // A category requested before its (asynchronously loaded) entries existed.
    onGeneratedChanged: {
        if (shown && path.length === 0 && ShellState.menuCategory !== "") enterRequestedCategory();
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
        opacity: root.shown ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: Style.animMs } }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.menuOpen = false
        }
    }

    ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Style.animMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "slide"; from: 14; to: 0; duration: Style.animMs; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card

        readonly property int rowHeight: 40

        width: Math.min(parent.width - 2 * Style.gap, Math.min(720, Math.max(480, parent.width * 0.4)))
        height: content.implicitHeight + 24
        property real slide: 0              // slides up into place while fading in
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.2) + slide
        radius: Style.menuRadius
        color: Colors.alpha(Colors.surface, Style.panelOpacity)
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
                font.pixelSize: 13
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

                onTextChanged: {
                    root.mouseMode = false;      // typing = keyboard mode
                    root.query = text;
                }
                onAccepted: root.run(root.rows[root.selected])

                Keys.onDownPressed: root.keySelect(root.selected + 1)
                Keys.onUpPressed: root.keySelect(root.selected - 1)
                Keys.onEscapePressed: {
                    if (root.pending !== null) root.pending = null;
                    else root.back();
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace && text === "" && root.path.length > 0) {
                        root.back();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        root.keySelect((root.selected + 1) % Math.max(1, root.rows.length));
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        root.keySelect(root.selected + root.pageSize);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        root.keySelect(root.selected - root.pageSize);
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
                        root.mouseMode = true;
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
                                    text: asking ? "Enter again to confirm" : item.modelData.subtitle
                                    visible: text !== ""
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: card.width * 0.45
                                    color: asking ? Colors.error : (item.active ? Colors.primaryContainerOn : Colors.surfaceVariantOn)
                                    font.bold: asking
                                    font.pixelSize: 13
                                }

                                Txt {
                                    visible: item.modelData.children
                                    text: "\uf105"
                                    color: item.active ? Colors.primaryContainerOn : Colors.surfaceVariantOn
                                }
                            }

                            // Hover selects only after the pointer REALLY moves. `entered` and
                            // synthetic hover events (menu opening, or the list scrolling under a
                            // resting pointer) are ignored, so the keyboard keeps control until
                            // you touch the mouse. A click always acts on the row you clicked.
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: mouse => {
                                    const p = item.mapToItem(null, mouse.x, mouse.y);
                                    if (root.lastX < 0) {            // first sighting: just remember it
                                        root.lastX = p.x;
                                        root.lastY = p.y;
                                        return;
                                    }
                                    if (Math.abs(p.x - root.lastX) + Math.abs(p.y - root.lastY) < 3) return;
                                    root.lastX = p.x;
                                    root.lastY = p.y;
                                    root.mouseMode = true;
                                    root.select(item.rowIndex);
                                }
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
                font.pixelSize: 12
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
