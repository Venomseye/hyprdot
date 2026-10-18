//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.bar
import qs.menu
import qs.notifications
import qs.osd
import qs.quick
import qs.wallpaper

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
    QuickSettings {}
    WallpaperPicker {}
    BatteryMonitor {}

    IpcHandler {
        target: "shell"

        function ping(): string {
            return "ok";
        }

        // ids: menu | history | quick | wallpapers | dnd | transparency | nightlight
        function toggle(id: string): void {
            switch (id) {
            case "menu": ShellState.toggleMenu(); break;
            case "history": ShellState.toggleHistory(); break;
            case "quick": ShellState.toggleQuick(); break;
            case "wallpapers": ShellState.toggleWallpapers(); break;
            case "dnd": ShellState.dnd = !ShellState.dnd; break;
            case "transparency": ShellState.barTransparent = !ShellState.barTransparent; break;
            case "nightlight": NightLight.toggle(); break;
            default: console.warn("shell toggle: unknown id '" + id + "'");
            }
        }

        // The menu with the calculator ready:  qs ipc call shell calc
        function calc(): void {
            ShellState.openMenu("", "=");
        }

        // Open the menu inside a category:  qs ipc call shell menu System
        function menu(category: string): void {
            ShellState.openMenu(category, "");
        }

        // Media keys and scripts:  qs ipc call shell media playpause|play|pause|stop|next|previous
        // Acts on the player the bar shows (a playing one first), see services/NowPlaying.qml.
        function media(action: string): void {
            NowPlaying.act(action);
        }

        // ids: updates
        function refresh(id: string): void {
            if (id === "updates") UpdateCheck.refresh();
        }

        function show(id: string): void {
            if (id === "menu") { ShellState.openMenu("", ""); return; }
            ShellState.closePanels();
            if (id === "history") ShellState.historyOpen = true;
            else if (id === "quick") ShellState.quickOpen = true;
            else if (id === "wallpapers") ShellState.wallpapersOpen = true;
        }

        function hide(id: string): void {
            if (id === "menu") ShellState.menuOpen = false;
            else if (id === "history") ShellState.historyOpen = false;
            else if (id === "quick") ShellState.quickOpen = false;
            else if (id === "wallpapers") ShellState.wallpapersOpen = false;
        }
    }
}
