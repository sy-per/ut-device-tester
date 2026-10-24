import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Wi-Fi scan through NetworkManager: passes if at least one network is visible.
TestBase {
    id: root
    timeoutMs: 20000

    Backend {
        id: backend
        onWifiFinished: {
            if (!ok) { root.fail(message); return }
            if (networks.length === 0) { root.fail(i18n.tr("No network visible")); return }
            var top = networks.slice(0, 3).map(function(n) { return n.ssid + " (" + n.strength + "%)" })
            root.pass(message + " : " + top.join(", "))
        }
    }

    function run() {
        note(i18n.tr("Scanning Wi-Fi…"))
        backend.startWifiScan()
    }
}
