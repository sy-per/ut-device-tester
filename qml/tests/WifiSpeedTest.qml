import QtQuick 2.12
import Lomiri.Components 1.3
import ".."

// Downloads 5 MB and computes the throughput of the active connection.
TestBase {
    id: root
    timeoutMs: 45000
    readonly property int bytes: 5000000
    property var xhr: null
    property double t0: 0

    function run() {
        note(i18n.tr("Downloading 5 MB…"))
        t0 = Date.now()
        xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            var secs = Math.max((Date.now() - t0) / 1000, 0.001)
            if (xhr.status !== 200) { root.fail(i18n.tr("Download failed (HTTP %1)").arg(xhr.status)); return }
            var got = xhr.responseText.length >= root.bytes / 2 ? xhr.responseText.length : root.bytes
            var mbps = got * 8 / 1e6 / secs
            var txt = i18n.tr("%1 Mbit/s (%2 MB in %3 s)").arg(mbps.toFixed(1)).arg((got / 1e6).toFixed(1)).arg(secs.toFixed(1))
            if (mbps < 1) root.fail(i18n.tr("Too slow: ") + txt)
            else root.pass(txt)
        }
        xhr.open("GET", "https://speed.cloudflare.com/__down?bytes=" + bytes)
        xhr.send()
    }
    function cleanup() { if (xhr) { xhr.onreadystatechange = null; xhr.abort() } }
}
