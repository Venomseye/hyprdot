import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.bar

// Now playing, at the top of Quick settings: rounded cover, title, artist, a progress line with
// times, and previous / play-pause / next. Hidden while nothing plays. (The bar only shows a
// small icon, see bar/Media.qml.)
Rectangle {
    id: root

    readonly property int coverSize: 68
    readonly property int coverRadius: 14
    // A frame in the card's own colour, concentric with the cover's rounded corners, hides the
    // square image corners (rounded cover without needing an opacity mask).
    readonly property int frame: Math.ceil(coverRadius * 0.45) + 1

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }

    visible: NowPlaying.active
    implicitHeight: visible ? content.implicitHeight + 28 : 0
    radius: Style.radius
    color: Colors.surfaceContainer
    border.width: 1
    border.color: Colors.outlineVariant

    // position is not pushed by MPRIS: poll once a second, only while Quick settings is open
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && ShellState.quickOpen
        onTriggered: NowPlaying.refreshPosition()
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize
                clip: true

                Item {
                    anchors.fill: parent
                    opacity: NowPlaying.playing ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 220 } }

                    Rectangle {
                        anchors.fill: parent
                        color: Colors.primaryContainer
                        Txt {
                            anchors.centerIn: parent
                            text: "\uf001"
                            font.pixelSize: 24
                            color: Colors.primaryContainerOn
                        }
                    }
                    Image {
                        anchors.fill: parent
                        source: NowPlaying.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 160
                        sourceSize.height: 160
                        visible: status === Image.Ready
                    }
                }

                Rectangle {
                    x: -root.frame
                    y: -root.frame
                    width: root.coverSize + 2 * root.frame
                    height: width
                    radius: root.coverRadius + root.frame
                    color: "transparent"
                    border.width: root.frame
                    border.color: Colors.surfaceContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Txt {
                    Layout.fillWidth: true
                    text: NowPlaying.title
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }
                Txt {
                    Layout.fillWidth: true
                    visible: NowPlaying.artist !== ""
                    text: NowPlaying.artist
                    font.pixelSize: 12
                    color: Colors.surfaceVariantOn
                    elide: Text.ElideRight
                }
                Txt {
                    Layout.fillWidth: true
                    visible: (NowPlaying.player?.identity ?? "") !== ""
                    text: NowPlaying.player?.identity ?? ""
                    font.pixelSize: 11
                    color: Colors.alpha(Colors.surfaceVariantOn, 0.7)
                    elide: Text.ElideRight
                }
            }
        }

        // progress (only for players that report a length)
        RowLayout {
            Layout.fillWidth: true
            visible: NowPlaying.length > 0
            spacing: 8

            Txt {
                text: root.fmt(NowPlaying.position)
                font.pixelSize: 11
                color: Colors.surfaceVariantOn
            }
            Rectangle {
                id: track
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: 2
                color: Colors.alpha(Colors.outline, 0.45)

                Rectangle {
                    width: NowPlaying.length > 0 ? track.width * Math.max(0, Math.min(1, NowPlaying.position / NowPlaying.length)) : 0
                    height: parent.height
                    radius: 2
                    color: Colors.primary
                    Behavior on width { NumberAnimation { duration: 900 } }
                }
            }
            Txt {
                text: root.fmt(NowPlaying.length)
                font.pixelSize: 11
                color: Colors.surfaceVariantOn
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\uf048"
                size: 38
                glyphSize: 13
                hoverColor: Colors.alpha(Colors.surfaceOn, 0.12)
                onClicked: NowPlaying.previous()
            }
            MediaButton {
                glyph: NowPlaying.playing ? "\uf04c" : "\uf04b"
                size: 48
                glyphSize: 17
                filled: true
                onClicked: NowPlaying.togglePlaying()
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\uf051"
                size: 38
                glyphSize: 13
                hoverColor: Colors.alpha(Colors.surfaceOn, 0.12)
                onClicked: NowPlaying.next()
            }
        }
    }
}
