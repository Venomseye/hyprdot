import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme

// Default microphone. Red crossed-out icon = muted, accent = live.
// left = mute/unmute, scroll = input volume.
BarItem {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audio: source?.audio ?? null
    readonly property bool muted: audio ? audio.muted : true

    visible: !!source

    PwObjectTracker { objects: [root.source] }

    onClicked: mouse => {
        if (audio && mouse.button === Qt.LeftButton) audio.muted = !audio.muted;
    }
    onScrolled: delta => {
        if (!audio) return;
        audio.volume = Math.max(0, Math.min(1, audio.volume + (delta > 0 ? 0.05 : -0.05)));
    }

    Txt {
        text: root.muted ? "\uf131" : "\uf130"
        color: root.muted ? Colors.error : Colors.primary
    }
}
