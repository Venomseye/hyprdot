import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.bar
import qs.menu
import qs.notifications
import qs.osd

// Entry point. Replaces Waybar (bar), Rofi (menu) and Mako (notifications).
//
//   bar/            the bar, one per screen
//   menu/           Super+Space menu
//   notifications/  notification daemon, banners, history, Do Not Disturb
//   osd/            volume OSD
//   services/       shared state, battery, low-battery hook trigger
//   theme/          Colors.qml (matugen output - never edit), Style.qml, Txt.qml
//
// Control it from outside with:  qs ipc call shell <function> [arg]
ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    MenuPanel {}
    Notifications {}
    Osd {}
    BatteryMonitor {}

    IpcHandler {
        target: "shell"

        function ping(): string {
            return "ok";
        }

        // ids: menu | history | dnd | transparency | nightlight
        function toggle(id: string): void {
            switch (id) {
            case "menu": ShellState.toggleMenu(); break;
            case "history": ShellState.toggleHistory(); break;
            case "dnd": ShellState.dnd = !ShellState.dnd; break;
            case "transparency": ShellState.barTransparent = !ShellState.barTransparent; break;
            case "nightlight": NightLight.toggle(); break;
            default: console.warn("shell toggle: unknown id '" + id + "'");
            }
        }

        // Open the menu inside a category:  qs ipc call shell menu System
        function menu(category: string): void {
            ShellState.openMenu(category);
        }

        // ids: updates
        function refresh(id: string): void {
            if (id === "updates") UpdateCheck.refresh();
        }

        function show(id: string): void {
            if (id === "menu") { ShellState.menuOpen = true; ShellState.historyOpen = false; }
            else if (id === "history") { ShellState.historyOpen = true; ShellState.menuOpen = false; }
        }

        function hide(id: string): void {
            if (id === "menu") ShellState.menuOpen = false;
            else if (id === "history") ShellState.historyOpen = false;
        }
    }
}
