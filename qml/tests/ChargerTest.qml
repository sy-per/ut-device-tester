import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Waits for the charger state to change (plug or unplug the cable).
TestBase {
    id: root
    timeoutMs: 45000
    property var initial: null

    Backend { id: backend }

    Timer { id: poll; interval: 500; repeat: true; onTriggered: root.check() }

    function check() {
        var b = backend.batteryInfo()
        if (b.charger === initial) return
        var kind = b.chargerType ? " (" + b.chargerType + ")" : ""
        pass(b.charger ? i18n.tr("Charger connected") + kind : i18n.tr("Charger disconnected"))
    }

    function run() {
        var b = backend.batteryInfo()
        if (!b.found) { fail(i18n.tr("No readable battery in /sys/class/power_supply")); return }
        initial = b.charger
        note(initial ? i18n.tr("Charger connected — unplug the cable") : i18n.tr("On battery — plug in the cable"))
        poll.start()
    }
    function cleanup() { poll.stop() }
}
