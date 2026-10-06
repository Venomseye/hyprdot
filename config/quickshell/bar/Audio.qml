import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme

// Volume icon. left/middle = pavucontrol, right = mute, scroll = volume
// (the OSD shows the level).
BarItem {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property real level: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    PwObjectTracker { objects: [root.sink] }

    onClicked: mouse => {
        if (!audio) return;
        if (mouse.button === Qt.RightButton) audio.muted = !audio.muted;
        else Quickshell.execDetached(["sh", "-c", "command -v pavucontrol >/dev/null 2>&1 && exec pavucontrol"]);
    }
    onScrolled: delta => {
        if (!audio) return;
        audio.volume = Math.max(0, Math.min(1, level + (delta > 0 ? 0.05 : -0.05)));
    }

    Txt {
        text: root.muted ? "\uf026" : root.level < 0.34 ? "\uf027" : "\uf028"
        color: root.muted ? Colors.error : Colors.surfaceOn
    }
}
