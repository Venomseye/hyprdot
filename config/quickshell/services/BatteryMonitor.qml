import QtQuick
import Quickshell
import qs.theme
import qs.services

// Fires the battery-low hooks once each time the charge drops to the
// threshold while discharging (re-arms after it goes back above).
Scope {
    id: root

    property int threshold: 15
    readonly property bool tripped: Battery.present && !Battery.charging && Battery.percent <= threshold

    function fire() {
        Quickshell.execDetached([
            Style.configHome + "/hooks/run-hooks", "battery-low", String(Battery.percent)
        ]);
    }

    onTrippedChanged: if (tripped) fire()
}
