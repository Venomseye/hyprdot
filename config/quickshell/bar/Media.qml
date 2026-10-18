import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services

// Now playing, in the bar: a round cover, "title . artist" and previous / play-pause / next
// buttons, in a pill. Hidden when nothing plays.
//   buttons = previous / play-pause / next
//   click on the pill = play / pause      right click = next track      (no scroll wheel)
// Title and artist are elided separately, so a long title never swallows the artist. Nothing
// scrolls (the tooltip has the full text), so a playing track does not keep the bar redrawing.
BarItem {
    id: root

    readonly property string line: NowPlaying.artist !== "" ? NowPlaying.title + "  \u00b7  " + NowPlaying.artist : NowPlaying.title
    readonly property int pillHeight: Style.barHeight - 8
    readonly property int coverSize: pillHeight - 6
    // Opaque on purpose: the cover's corner mask below has to match it exactly.
    readonly property bool pillHovered: root.hovered || prevButton.hovered || playButton.hovered || nextButton.hovered
    readonly property color pillColor: pillHovered ? Colors.surfaceContainerHighest : Colors.surfaceContainer

    // Room the bar gives the pill (set in Bar.qml). Also capped, so it stays tidy on ultrawide screens.
    property real maxWidth: 420

    visible: NowPlaying.active
    showHover: false
    horizontalPadding: 4
    tooltip: root.line + "\nclick: play/pause   right-click: next"

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) NowPlaying.next();
        else NowPlaying.togglePlaying();
    }

    Rectangle {
        id: pill

        // How the room is shared. Everything that is not text is fixed; the rest is the text budget.
        readonly property real fixedWidth: 3 + root.coverSize + 8 + 8 + controls.width + 4
        readonly property real budget: Math.max(40, Math.min(root.maxWidth, 420) - 8 - fixedWidth)
        readonly property real titleNat: measureTitle.implicitWidth
        readonly property real artistNat: NowPlaying.artist !== "" ? measureArtist.implicitWidth : 0
        readonly property real avail: Math.max(20, budget - (artistNat > 0 ? 16 : 0))
        // The artist keeps at least ~38% of the room when it needs it; a short title leaves more.
        readonly property real artistWidth: {
            if (artistNat === 0) return 0;
            if (titleNat + artistNat <= avail) return artistNat;
            const w = Math.min(artistNat, Math.max(avail * 0.38, avail - titleNat));
            return w < 36 ? 0 : w;
        }
        readonly property real titleWidth: Math.min(titleNat, artistWidth > 0 ? avail - artistWidth : budget)

        // The text box grows and shrinks smoothly when the track changes (the pill is anchored
        // on its right edge, so it moves left instead of jumping).
        property real textWidth: titleWidth + (artistWidth > 0 ? 16 + artistWidth : 0)
        Behavior on textWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Layout.preferredHeight: root.pillHeight
        Layout.preferredWidth: 3 + root.coverSize + 8 + textWidth + 8 + controls.width + 4
        radius: height / 2
        color: root.pillColor
        Behavior on color { ColorAnimation { duration: 120 } }

        // Invisible copies of the text, only to measure how wide each part wants to be.
        Txt {
            id: measureTitle
            visible: false
            text: NowPlaying.title
            font.pixelSize: 13
        }
        Txt {
            id: measureArtist
            visible: false
            text: NowPlaying.artist
            font.pixelSize: 13
        }

        // ---- round cover -----------------------------------------------------------------
        Item {
            id: cover
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            width: root.coverSize
            height: root.coverSize
            clip: true

            // The artwork alone is dimmed when paused. The ring below must stay fully opaque:
            // it is what hides the square's corners, and a translucent ring lets them show.
            Item {
                anchors.fill: parent
                opacity: NowPlaying.playing ? 1 : 0.65
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Rectangle {
                    anchors.fill: parent
                    color: Colors.primaryContainer

                    Txt {
                        anchors.centerIn: parent
                        text: "\uf001"
                        font.pixelSize: 11
                        color: Colors.primaryContainerOn
                    }
                }

                Image {
                    anchors.fill: parent
                    source: NowPlaying.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 64
                    sourceSize.height: 64
                    visible: status === Image.Ready
                }
            }

            // A thick ring in the pill's own colour hides the square's corners: round cover,
            // no clipping effect needed.
            Rectangle {
                anchors.centerIn: parent
                width: root.coverSize + 14
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 7
                border.color: root.pillColor
            }
        }

        // ---- title  .  artist --------------------------------------------------------------------
        Item {
            id: textBox
            x: 3 + root.coverSize + 8
            anchors.verticalCenter: parent.verticalCenter
            width: pill.textWidth
            height: parent.height
            clip: true          // while the pill is still growing or shrinking

            Txt {
                id: titleText
                width: pill.titleWidth
                anchors.verticalCenter: parent.verticalCenter
                text: NowPlaying.title
                font.pixelSize: 13
                elide: Text.ElideRight
                color: NowPlaying.playing ? Colors.surfaceOn : Colors.surfaceVariantOn
            }

            Txt {
                x: pill.titleWidth + 5
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.artistWidth > 0
                text: "\u00b7"
                font.pixelSize: 13
                color: Colors.outline
            }

            Txt {
                x: pill.titleWidth + 16
                width: pill.artistWidth
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.artistWidth > 0
                text: NowPlaying.artist
                font.pixelSize: 13
                elide: Text.ElideRight
                color: Colors.surfaceVariantOn
            }
        }

        // ---- buttons ------------------------------------------------------------------------------
        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            MediaButton {
                id: prevButton
                glyph: "\uf048"
                size: 22
                glyphSize: 11
                hoverColor: Colors.alpha(Colors.surfaceOn, 0.14)
                onClicked: NowPlaying.previous()
            }
            MediaButton {
                id: playButton
                glyph: NowPlaying.playing ? "\uf04c" : "\uf04b"
                size: 22
                glyphSize: 10
                filled: true
                onClicked: NowPlaying.togglePlaying()
            }
            MediaButton {
                id: nextButton
                glyph: "\uf051"
                size: 22
                glyphSize: 11
                hoverColor: Colors.alpha(Colors.surfaceOn, 0.14)
                onClicked: NowPlaying.next()
            }
        }
    }

}
