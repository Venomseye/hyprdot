import QtQuick
import QtQuick.Layouts
import qs.theme

// A bar glyph in a fixed-width box. Nerd Font icons have very different natural widths (a check
// mark is narrow, a sun or a sitemap is wide), which made the gaps between bar icons uneven.
Txt {
    Layout.preferredWidth: Style.iconBox
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.pixelSize: Style.iconSize
}
