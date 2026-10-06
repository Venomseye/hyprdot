import QtQuick
import qs.theme
import qs.services

// Night light (hyprsunset). Moon = on, sun = off, dim sun = hyprsunset missing.
// left = toggle.
BarItem {
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) NightLight.toggle();
    }

    Txt {
        text: NightLight.active ? "\uf186" : "\uf185"
        color: !NightLight.available ? Colors.outline
             : NightLight.active ? Colors.tertiary
             : Colors.surfaceVariantOn
    }
}
