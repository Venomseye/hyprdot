pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery facts for the bar and BatteryMonitor. Needs the upower daemon.
Singleton {
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev ? dev.isPresent : false

    // UPower reports 0..1 in Quickshell; tolerate 0..100 too.
    readonly property real raw: dev ? dev.percentage : 0
    readonly property int percent: Math.round(raw <= 1 ? raw * 100 : raw)

    readonly property bool charging: dev ? dev.state === UPowerDeviceState.Charging : false
    readonly property bool low: present && !charging && percent <= 15

    readonly property string glyph: {
        if (charging) return "\uf0e7";
        if (percent > 87) return "\uf240";
        if (percent > 62) return "\uf241";
        if (percent > 37) return "\uf242";
        if (percent > 12) return "\uf243";
        return "\uf244";
    }
}
