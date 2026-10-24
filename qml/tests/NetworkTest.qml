import QtQuick 2.12
import Lomiri.Components 1.3
import ".."

// Reaches a test server (HTTP 204). To test Wi-Fi alone, turn off mobile data.
TestBase {
    id: root
    timeoutMs: 15000
    property var xhr: null
    property double t0: 0

    function systemInfo() {
        try {
            var o = Qt.createQmlObject('import QtQuick 2.12; import Lomiri.Connectivity 1.0; QtObject { property var st: NetworkingStatus.status }', root)
            var s = "NetworkingStatus=" + o.st
            o.destroy()
            return s
        } catch (e) {
            return ""
        }
    }

    function run() {
        var info = systemInfo()
        t0 = Date.now()
        xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            var ms = Date.now() - t0
            if (xhr.status === 204 || xhr.status === 200)
                root.pass(i18n.tr("Internet OK (%1 ms)").arg(ms) + (info ? " — " + info : ""))
            else
                root.fail(i18n.tr("No internet access (HTTP %1)").arg(xhr.status) + (info ? " — " + info : ""))
        }
        xhr.open("GET", "http://connectivitycheck.gstatic.com/generate_204")
        xhr.send()
    }
    function cleanup() { if (xhr) { xhr.onreadystatechange = null; xhr.abort() } }
}
