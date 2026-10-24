import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Reads memory and storage figures.
TestBase {
    id: root

    Backend { id: backend }

    function gb(mb) { return (mb / 1024).toFixed(1) }

    function run() {
        var d = backend.deviceInfo()
        if (d.memTotalMB <= 0 || d.storageTotalMB <= 0) { fail(i18n.tr("Could not read memory or storage")); return }
        var txt = i18n.tr("RAM: %1 GB free of %2 GB").arg(gb(d.memAvailMB)).arg(gb(d.memTotalMB))
                  + "\n" + i18n.tr("Storage: %1 GB free of %2 GB").arg(gb(d.storageFreeMB)).arg(gb(d.storageTotalMB))
        if (d.storageFreeMB < 200) fail(i18n.tr("Almost no free storage") + "\n" + txt)
        else pass(txt)
    }
}
