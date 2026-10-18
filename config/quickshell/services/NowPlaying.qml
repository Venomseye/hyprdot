pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// What is playing, for the bar's media pill and the media keys (`qs ipc call shell media ...`),
// so both always mean the same player.
Singleton {
    id: root

    // Real players only. playerctld exposes a proxy that mirrors whichever player was used
    // last, which would otherwise show up as a second copy of the same track.
    readonly property var players: Mpris.players.values.filter(p => !(p.dbusName ?? "").includes("playerctld"))

    // One that is playing right now, else the first one.
    readonly property var player: root.players.find(p => p.isPlaying) ?? root.players[0] ?? null

    readonly property bool active: root.player !== null && root.title !== ""
    readonly property bool playing: root.player ? root.player.isPlaying : false
    readonly property string title: (root.player?.trackTitle ?? "").trim()
    readonly property string artist: (root.player?.trackArtist ?? "").trim()
    readonly property string artUrl: root.player?.trackArtUrl ?? ""

    function togglePlaying() { if (root.player) root.player.togglePlaying(); }
    function next() { if (root.player) root.player.next(); }
    function previous() { if (root.player) root.player.previous(); }

    // Used by the IPC handler in shell.qml:  qs ipc call shell media <action>
    function act(action) {
        switch (action) {
        case "playpause": case "toggle": root.togglePlaying(); break;
        case "play": if (root.player) root.player.play(); break;
        case "pause": if (root.player) root.player.pause(); break;
        case "stop": if (root.player) root.player.stop(); break;
        case "next": root.next(); break;
        case "previous": case "prev": root.previous(); break;
        default: console.warn("media: unknown action '" + action + "'");
        }
    }
}
