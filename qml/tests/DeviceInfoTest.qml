import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Collects model, system, kernel and CPU information.
TestBase {
    id: root

    Backend { id: backend }

    function run() {
        var d = backend.deviceInfo()
        if (!d.os) { fail(i18n.tr("Could not read device information")); return }
        var lines = []
        if (d.model) lines.push(d.model)
        lines.push(d.os + (d.channel ? " (" + d.channel + ")" : ""))
        lines.push(i18n.tr("Kernel %1 (%2)").arg(d.kernel).arg(d.arch))
        lines.push(i18n.tr("CPU: %1 cores, up to %2 MHz").arg(d.cpuCores).arg(d.cpuMaxMHz))
        lines.push(i18n.tr("RAM: %1 GB").arg((d.memTotalMB / 1024).toFixed(1)))
        pass(lines.join("\n"))
    }
}
