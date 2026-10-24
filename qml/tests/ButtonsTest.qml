import QtQuick 2.12
import Lomiri.Components 1.3
import ".."

// Volume up / down buttons (the system may intercept them depending on the version).
TestBase {
    id: root
    timeoutMs: 20000
    property bool up: false
    property bool down: false

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: {
            if (event.key === Qt.Key_VolumeUp) root.up = true
            else if (event.key === Qt.Key_VolumeDown) root.down = true
            root.note(i18n.tr("Volume up: %1   Volume down: %2   (key %3)").arg(root.up ? "OK" : "…").arg(root.down ? "OK" : "…").arg(event.key))
            if (root.up && root.down) root.pass(i18n.tr("Volume up and down detected"))
            event.accepted = true
        }
    }

    function run() { keys.forceActiveFocus(); note(i18n.tr("Press Volume up then Volume down")) }
}
