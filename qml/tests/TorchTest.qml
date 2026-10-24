import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Flashlight: flash LED driven through sysfs (DeviceBackend plugin).
TestBase {
    id: root
    timeoutMs: 20000

    Backend { id: backend }

    function run() {
        if (!backend.setTorch(true)) { fail(i18n.tr("Flashlight LED not accessible (/sys/class/leds)")); return }
        note(i18n.tr("Flashlight on"))
        root.ask(i18n.tr("Is the flashlight on?"))
    }
    function cleanup() { backend.setTorch(false) }
}
