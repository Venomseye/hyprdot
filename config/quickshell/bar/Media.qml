import QtQuick
import qs.theme
import qs.services

// Now playing, in the bar: one small icon, shown only while a player has a track.
//   left click = play / pause    middle click = next    right click = the full card in Quick settings
//   scroll = next / previous     hover = "title - artist"
// The cover, title and previous/play/next buttons live in the Quick settings card
// (quick/NowPlayingCard.qml), so the bar stays as quiet as every other item.
BarItem {
    id: root

    readonly property string line: NowPlaying.artist !== "" ? NowPlaying.title + "  \u00b7  " + NowPlaying.artist : NowPlaying.title

    visible: NowPlaying.active
    tooltip: root.line + "\nclick: play/pause   middle: next   right-click: player"

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) ShellState.toggleQuick();
        else if (mouse.button === Qt.MiddleButton) NowPlaying.next();
        else NowPlaying.togglePlaying();
    }
    onScrolled: delta => {
        if (delta > 0) NowPlaying.previous();
        else NowPlaying.next();
    }

    BarIcon {
        text: NowPlaying.playing ? "\uf001" : "\uf04c"
        color: NowPlaying.playing ? Colors.primary : Colors.surfaceVariantOn
    }
}
