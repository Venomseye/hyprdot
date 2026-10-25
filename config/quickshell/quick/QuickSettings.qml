import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.theme
import qs.services

// Quick settings (Super+A, or the sliders icon on the bar): volume, microphone and
// brightness sliders, toggle tiles, and expandable lists for audio output, Wi-Fi
// networks and Bluetooth devices. Closes on Esc, a click outside, or Style.panelIdleMs
// after the pointer leaves it.
PanelWindow {
    id: root

    readonly property bool shown: ShellState.quickOpen
    property string section: ""          // which list is expanded: "" | audio | wifi | bluetooth

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => {
        const cls = n.properties ? (n.properties["media.class"] ?? "") : "Audio/Sink";
        return n.isSink && !n.isStream && cls === "Audio/Sink";
    })

    PwObjectTracker { objects: [root.sink, root.source].filter(o => o) }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: Style.barHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "qs-quick"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!shown) return;
        section = "";
        Brightness.refresh();
        NetState.refresh();
        BtState.refresh();
        Caffeine.refresh();
        PowerProfile.refresh();
        NightLight.refresh();
        appear.restart();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    function toggleSection(name) {
        section = section === name ? "" : name;
        if (section === "wifi") NetState.scan();
        if (section === "bluetooth") BtState.refresh();
    }

    // closes after a while - but only once the pointer has left the panel
    Timer {
        interval: Style.panelIdleMs
        running: root.shown && !hover.hovered
        onTriggered: ShellState.quickOpen = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.quickOpen = false
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.quickOpen = false
    }

    ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Style.animMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "slide"; from: -12; to: 0; duration: Style.animMs; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card

        property real slide: 0
        anchors.right: parent.right
        anchors.rightMargin: Style.gap
        y: Style.gap + slide
        width: Math.min(420, parent.width - 2 * Style.gap)
        // as tall as its content, but never taller than the screen - then it scrolls
        height: Math.min(content.implicitHeight + 28, parent.height - 2 * Style.gap)
        radius: Style.radius
        color: Colors.alpha(Colors.surface, Style.panelOpacity)
        border.width: 1
        border.color: Colors.outlineVariant

        HoverHandler { id: hover }
        MouseArea { anchors.fill: parent }       // swallow clicks on the card

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 14
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content
                width: flick.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Txt {
                        text: "Quick settings"
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Txt {
                        text: "\uf00d"
                        color: Colors.surfaceVariantOn
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: ShellState.quickOpen = false
                        }
                    }
                }

                // ---- sliders
                SliderRow {
                    glyph: (root.sink?.audio?.muted ?? false) ? "\uf026" : (root.sink?.audio?.volume ?? 0) < 0.34 ? "\uf027" : "\uf028"
                    value: root.sink?.audio?.volume ?? 0
                    muted: root.sink?.audio?.muted ?? false
                    visible: !!root.sink
                    onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = v; }
                    onGlyphClicked: { if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted; }
                }

                SliderRow {
                    glyph: (root.source?.audio?.muted ?? true) ? "\uf131" : "\uf130"
                    value: root.source?.audio?.volume ?? 0
                    muted: root.source?.audio?.muted ?? true
                    visible: !!root.source
                    onMoved: v => { if (root.source?.audio) root.source.audio.volume = v; }
                    onGlyphClicked: { if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted; }
                }

                SliderRow {
                    glyph: "\uf185"
                    value: Brightness.level
                    visible: Brightness.available
                    onMoved: v => Brightness.set(v)
                }

                // ---- toggles
                GridLayout {
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8
                    Layout.fillWidth: true

                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        visible: NetState.available && NetState.hasWifi
                        glyph: "\uf1eb"
                        label: "Wi-Fi"
                        sub: NetState.label
                        active: NetState.wifiEnabled
                        onClicked: NetState.toggleWifi()
                    }
                    // No Wi-Fi adapter (a desktop, a VM): the Wi-Fi tile is hidden, so without this there
                    // would be no network entry here at all. Shows the wired connection; click opens nmtui.
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        visible: NetState.available && !NetState.hasWifi
                        glyph: "\uf0ac"
                        label: NetState.kind === "ethernet" ? "Ethernet" : "Network"
                        sub: NetState.kind === "none" ? "Not connected" : (NetState.ssid !== "" ? NetState.ssid : NetState.label)
                        active: NetState.kind !== "none"
                        onClicked: {
                            ShellState.quickOpen = false;
                            Run.sh("command -v nmtui >/dev/null 2>&1 && exec kitty --title=nmtui -e nmtui");
                        }
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        visible: BtState.available
                        glyph: "\uf293"
                        label: "Bluetooth"
                        sub: !BtState.powered ? "Off" : BtState.connected > 0 ? BtState.connected + " connected" : "On"
                        active: BtState.powered
                        onClicked: BtState.togglePower()
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        glyph: "\uf1f6"
                        label: "Do not disturb"
                        sub: ShellState.dnd ? "On" : "Off"
                        active: ShellState.dnd
                        onClicked: ShellState.dnd = !ShellState.dnd
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        glyph: "\uf186"
                        label: "Night light"
                        sub: !NightLight.available ? "hyprsunset missing" : NightLight.active ? "On" : "Off"
                        active: NightLight.active
                        onClicked: NightLight.toggle()
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        visible: Caffeine.available
                        glyph: "\uf0f4"
                        label: "Stay awake"
                        sub: Caffeine.active ? "Screen won't sleep" : "Off"
                        active: Caffeine.active
                        onClicked: Caffeine.toggle()
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        visible: PowerProfile.available
                        glyph: "\uf0e7"
                        label: "Power profile"
                        sub: PowerProfile.label
                        active: PowerProfile.profile !== "balanced"
                        onClicked: PowerProfile.cycle()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.outlineVariant
                }

                // ---- lists: one open at a time, each scrolls inside a fixed maximum height
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    SectionHeader {
                        Layout.fillWidth: true
                        label: "Audio output"
                        sub: root.sink?.description ?? ""
                        expanded: root.section === "audio"
                        onClicked: root.toggleSection("audio")
                    }
                    ScrollList {
                        Layout.fillWidth: true
                        visible: root.section === "audio"
                        Repeater {
                            model: root.sinks
                            delegate: ListRow {
                                required property var modelData
                                width: parent.width
                                glyph: modelData === root.sink ? "\uf00c" : "\uf028"
                                title: modelData.description || modelData.nickname || modelData.name
                                active: modelData === root.sink
                                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                        Txt {
                            visible: root.sinks.length === 0
                            width: parent.width
                            leftPadding: 10
                            text: "No output devices found"
                            color: Colors.surfaceVariantOn
                        }
                    }

                    SectionHeader {
                        Layout.fillWidth: true
                        visible: NetState.available && NetState.hasWifi
                        label: "Wi-Fi networks"
                        sub: NetState.kind === "wifi" ? NetState.ssid : ""
                        expanded: root.section === "wifi"
                        onClicked: root.toggleSection("wifi")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.section === "wifi" && NetState.available && NetState.hasWifi
                        spacing: 4

                        ScrollList {
                            Layout.fillWidth: true
                            Repeater {
                                model: NetState.networks
                                delegate: ListRow {
                                    required property var modelData
                                    width: parent.width
                                    glyph: modelData.active ? "\uf00c" : "\uf1eb"
                                    title: modelData.ssid
                                    bars: modelData.signal
                                    detail: NetState.connecting === modelData.ssid ? "connecting..."
                                          : modelData.active ? "connected"
                                          : modelData.secure ? "\uf023" : ""
                                    active: modelData.active
                                    onClicked: { if (!modelData.active && NetState.connecting === "") NetState.connectTo(modelData.ssid); }
                                }
                            }
                            Txt {
                                visible: NetState.networks.length === 0
                                width: parent.width
                                leftPadding: 10
                                text: !NetState.wifiEnabled ? "Wi-Fi is off" : NetState.scanning ? "Scanning..." : "No networks found - try Rescan"
                                color: Colors.surfaceVariantOn
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            spacing: 10

                            Txt {
                                text: "New secured network? Right-click the Wi-Fi icon (nmtui)."
                                color: Colors.surfaceVariantOn
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            Txt {
                                text: NetState.scanning ? "\uf021  Scanning..." : "\uf021  Rescan"
                                color: NetState.scanning ? Colors.surfaceVariantOn : Colors.primary
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    enabled: !NetState.scanning
                                    onClicked: NetState.scan()
                                }
                            }
                        }
                    }

                    SectionHeader {
                        Layout.fillWidth: true
                        visible: BtState.available
                        label: "Bluetooth devices"
                        sub: BtState.connected > 0 ? BtState.connected + " connected" : ""
                        expanded: root.section === "bluetooth"
                        onClicked: root.toggleSection("bluetooth")
                    }
                    ScrollList {
                        Layout.fillWidth: true
                        visible: root.section === "bluetooth" && BtState.available
                        Repeater {
                            model: BtState.devices
                            delegate: ListRow {
                                required property var modelData
                                width: parent.width
                                glyph: "\uf293"
                                title: modelData.name
                                detail: modelData.connected ? "connected" : ""
                                active: modelData.connected
                                onClicked: BtState.toggleDevice(modelData)
                            }
                        }
                        Txt {
                            visible: BtState.devices.length === 0
                            width: parent.width
                            leftPadding: 10
                            text: BtState.powered ? "No paired devices" : "Bluetooth is off"
                            color: Colors.surfaceVariantOn
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.outlineVariant
                }

                // ---- shortcuts
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 40
                        compact: true
                        glyph: "\uf03e"
                        label: "Wallpaper"
                        onClicked: ShellState.toggleWallpapers()
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 40
                        compact: true
                        glyph: "\uf023"
                        label: "Lock"
                        onClicked: {
                            ShellState.quickOpen = false;
                            Run.sh("dot-power lock");
                        }
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 40
                        compact: true
                        glyph: "\uf011"
                        label: "Power"
                        onClicked: ShellState.openMenu("System")
                    }
                }
            }
        }
    }
}
