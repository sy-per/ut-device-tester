import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Waits for a headset to be plugged in (it must be unplugged first).
TestBase {
    id: root
    timeoutMs: 45000
    property bool seenUnplugged: false

    Backend { id: backend }

    Timer { id: poll; interval: 400; repeat: true; onTriggered: root.check() }

    function check() {
        var s = backend.headsetState()
        if (s === 0) {
            if (!seenUnplugged) note(i18n.tr("Plug in a headset or headphones"))
            seenUnplugged = true
        } else if (s > 0) {
            if (seenUnplugged) pass(s === 1 ? i18n.tr("Headset with microphone detected") : i18n.tr("Headphones detected"))
            else note(i18n.tr("Headset already plugged in — unplug it, then plug it back"))
        }
    }

    function run() {
        if (backend.headsetState() < 0) { fail(i18n.tr("Headset detection not available on this device")); return }
        check()
        poll.start()
    }
    function cleanup() { poll.stop() }
}
