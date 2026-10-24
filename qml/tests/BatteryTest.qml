import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

TestBase {
    id: root

    Backend { id: backend }

    function run() {
        var b = backend.batteryInfo()
        if (!b.found) { fail(i18n.tr("No readable battery in /sys/class/power_supply")); return }
        var txt = b.capacity + " % — " + b.status
        if (b.voltage > 0) txt += ", " + b.voltage.toFixed(2) + " V"
        if (b.temperature !== null && b.temperature !== undefined) txt += ", " + b.temperature.toFixed(1) + " °C"
        if (b.health) txt += i18n.tr(", health: ") + b.health
        txt += b.charger ? i18n.tr(" (charger connected)") : i18n.tr(" (on battery)")
        if (b.capacity < 0 || b.capacity > 100) fail(txt)
        else pass(txt)
    }
}
