import QtQuick
import Quickshell
import qs.theme
import qs.services

// Fires the battery-low hooks once when the charge really drops to the threshold while
// discharging (re-arms after it goes back above). Guards against the false alarm you get
// at boot/reload, when UPower briefly reads 0%: values only count once they are known,
// ten seconds after start, and still true four seconds after they first look low.
Scope {
    id: root

    property int threshold: 15
    property bool armed: false
    property bool fired: false
    readonly property bool tripped: Battery.known && !Battery.charging && Battery.percent <= threshold

    function fire() {
        Quickshell.execDetached([
            Style.configHome + "/hooks/run-hooks", "battery-low", String(Battery.percent)
        ]);
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: confirm
        interval: 4000
        onTriggered: {
            if (root.armed && root.tripped && !root.fired) {
                root.fired = true;
                root.fire();
            }
        }
    }

    onTrippedChanged: {
        if (tripped) {
            confirm.restart();
        } else {
            confirm.stop();
            fired = false;
        }
    }
    onArmedChanged: if (armed && tripped) confirm.restart()
}
