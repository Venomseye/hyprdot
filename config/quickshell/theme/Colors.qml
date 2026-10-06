pragma Singleton

import QtQuick
import Quickshell

// BOOTSTRAP placeholder (fallback palette) - matugen overwrites this file on the first wallpaper change.
// Edit the template, then change wallpaper to regenerate.
//
// Material Design 3 roles, camelCased. The M3 "on-" (content) roles end in
// "On" - primaryOn, surfaceOn, ... - because QML reserves on<Name> for signal
// handlers and refuses a property called onPrimary. Every other QML file reads colours from
// here (Colors.primary, Colors.surfaceOn, ...) - never hardcode a hex value.
Singleton {
    readonly property string mode: "dark"
    readonly property color sourceColor: "#33ccff"

    // Primary
    readonly property color primary: "#8ed1ff"
    readonly property color primaryOn: "#00344b"
    readonly property color primaryContainer: "#004c6a"
    readonly property color primaryContainerOn: "#c6e7ff"
    readonly property color primaryFixed: "#c6e7ff"
    readonly property color primaryFixedDim: "#8ed1ff"
    readonly property color primaryFixedOn: "#001e2e"
    readonly property color primaryFixedVariantOn: "#004c6a"

    // Secondary
    readonly property color secondary: "#b4cad6"
    readonly property color secondaryOn: "#1f333d"
    readonly property color secondaryContainer: "#354a54"
    readonly property color secondaryContainerOn: "#d0e6f2"
    readonly property color secondaryFixed: "#d0e6f2"
    readonly property color secondaryFixedDim: "#b4cad6"
    readonly property color secondaryFixedOn: "#081e27"
    readonly property color secondaryFixedVariantOn: "#354a54"

    // Tertiary
    readonly property color tertiary: "#c9c2ea"
    readonly property color tertiaryOn: "#312c4c"
    readonly property color tertiaryContainer: "#484264"
    readonly property color tertiaryContainerOn: "#e5deff"
    readonly property color tertiaryFixed: "#e5deff"
    readonly property color tertiaryFixedDim: "#c9c2ea"
    readonly property color tertiaryFixedOn: "#1c1736"
    readonly property color tertiaryFixedVariantOn: "#484264"

    // Error
    readonly property color error: "#ffb4ab"
    readonly property color errorOn: "#690005"
    readonly property color errorContainer: "#93000a"
    readonly property color errorContainerOn: "#ffdad6"

    // Surfaces
    readonly property color background: "#0f1417"
    readonly property color backgroundOn: "#dee3e7"
    readonly property color surface: "#0f1417"
    readonly property color surfaceDim: "#0f1417"
    readonly property color surfaceBright: "#353a3d"
    readonly property color surfaceContainerLowest: "#0a0f11"
    readonly property color surfaceContainerLow: "#171c1f"
    readonly property color surfaceContainer: "#1b2023"
    readonly property color surfaceContainerHigh: "#262b2e"
    readonly property color surfaceContainerHighest: "#303538"
    readonly property color surfaceVariant: "#40484d"
    readonly property color surfaceTint: "#8ed1ff"
    readonly property color surfaceOn: "#dee3e7"
    readonly property color surfaceVariantOn: "#c0c7cd"

    // Outline, inverse, misc
    readonly property color outline: "#8a9297"
    readonly property color outlineVariant: "#40484d"
    readonly property color inverseSurface: "#dee3e7"
    readonly property color inverseOnSurface: "#2c3134"
    readonly property color inversePrimary: "#086584"
    readonly property color scrim: "#000000"
    readonly property color shadow: "#000000"

    // Same colour with a different opacity: Colors.alpha(Colors.scrim, 0.35)
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
