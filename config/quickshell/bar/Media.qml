import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.theme

// MPRIS now-playing with a scrolling title.
// left = play/pause, middle = next, scroll = previous/next. Hidden when idle.
BarItem {
    id: root

    // playerctld exposes a proxy player that mirrors the real one - skip it.
    readonly property var players: Mpris.players.values.filter(p => !(p.dbusName ?? "").includes("playerctld"))
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property string title: {
        if (!player) return "";
        const t = (player.trackTitle ?? "").trim();
        const a = (player.trackArtist ?? "").trim();
        return a !== "" ? t + "  -  " + a : t;
    }

    visible: player !== null && title !== ""

    onClicked: mouse => {
        if (!player) return;
        if (mouse.button === Qt.MiddleButton) player.next();
        else if (mouse.button === Qt.LeftButton) player.togglePlaying();
    }
    onScrolled: delta => {
        if (!player) return;
        if (delta > 0) player.previous(); else player.next();
    }

    Txt {
        text: root.player?.isPlaying ? "\uf04b" : "\uf04c"
        color: Colors.primary
        font.pixelSize: 11
    }

    Item {
        id: viewport
        Layout.preferredWidth: Math.min(label.implicitWidth, 240)
        Layout.preferredHeight: Style.barHeight
        clip: true

        Txt {
            id: label
            text: root.title
            anchors.verticalCenter: parent.verticalCenter

            onTextChanged: x = 0

            SequentialAnimation on x {
                running: label.implicitWidth > viewport.width && root.visible && root.player?.isPlaying
                loops: Animation.Infinite
                PauseAnimation { duration: 1500 }
                NumberAnimation {
                    to: -(label.implicitWidth - viewport.width)
                    duration: Math.max(1, (label.implicitWidth - viewport.width) * 30)
                    easing.type: Easing.Linear
                }
                PauseAnimation { duration: 1500 }
                NumberAnimation { to: 0; duration: 500 }
            }
        }
    }
}
