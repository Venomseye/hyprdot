pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Shared UI state. The persisted fields are written to
// ~/.local/state/quickshell-dot/state.json so they survive a shell restart
// (dot-reload shell). Nothing here lives inside the config dir, so saving
// never triggers a Quickshell live-reload.
Singleton {
    id: root

    // Transient
    property bool menuOpen: false
    property string menuCategory: ""     // open the menu inside this category (e.g. "System")
    property string menuQuery: ""        // ...with this already typed (e.g. "=" for the calculator)
    property bool quickOpen: false
    property bool wallpapersOpen: false
    property bool historyOpen: false

    // Persisted
    property bool dnd: false
    property bool barTransparent: false
    property int clockFormat: 1
    property bool batteryPercent: true

    property bool ready: false
    property bool dirty: false
    readonly property string statePath: Style.stateHome + "/quickshell-dot/state.json"

    // Only one overlay panel is open at a time; each toggle closes the others first.
    function closePanels() {
        menuOpen = false;
        historyOpen = false;
        quickOpen = false;
        wallpapersOpen = false;
    }

    function toggleMenu() {
        const was = menuOpen;
        closePanels();
        menuCategory = "";
        menuQuery = "";
        menuOpen = !was;
    }

    // Open the menu inside a category and/or with a query already typed
    // (openMenu("Clipboard"), openMenu("", "=") for the calculator).
    function openMenu(category, query) {
        closePanels();
        menuCategory = category || "";
        menuQuery = query || "";
        menuOpen = true;
    }

    function toggleHistory() {
        const was = historyOpen;
        closePanels();
        historyOpen = !was;
    }

    function toggleQuick() {
        const was = quickOpen;
        closePanels();
        quickOpen = !was;
    }

    function toggleWallpapers() {
        const was = wallpapersOpen;
        closePanels();
        wallpapersOpen = !was;
    }

    function parse(text) {
        try {
            const s = JSON.parse(text);
            if (typeof s.dnd === "boolean") dnd = s.dnd;
            if (typeof s.barTransparent === "boolean") barTransparent = s.barTransparent;
            if (typeof s.clockFormat === "number") clockFormat = s.clockFormat;
            if (typeof s.batteryPercent === "boolean") batteryPercent = s.batteryPercent;
        } catch (e) {
            console.warn("ShellState: ignoring unreadable " + statePath + ": " + e);
        }
    }

    function save() {
        if (!ready) return;
        if (writer.running) { dirty = true; return; }
        writer.command = [
            "sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "sh",
            statePath,
            JSON.stringify({ dnd: dnd, barTransparent: barTransparent, clockFormat: clockFormat, batteryPercent: batteryPercent })
        ];
        writer.running = true;
    }

    onDndChanged: save()
    onBarTransparentChanged: save()
    onClockFormatChanged: save()
    onBatteryPercentChanged: save()

    Process {
        id: writer
        onExited: {
            if (root.dirty) {
                root.dirty = false;
                root.save();
            }
        }
    }

    FileView {
        path: root.statePath
        onLoaded: { root.parse(text()); root.ready = true; }
        onLoadFailed: root.ready = true   // first run: no file yet
    }
}
