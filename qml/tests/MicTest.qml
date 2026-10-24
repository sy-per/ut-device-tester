import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Enregistre 3 s et mesure le niveau : parlez ou tapotez le micro.
TestBase {
    id: root
    timeoutMs: 15000
    readonly property real minPeakDb: -40

    Backend {
        id: backend
        onMicFinished: {
            var lv = i18n.tr("RMS %1 dBFS, peak %2 dBFS").arg(rmsDb.toFixed(1)).arg(peakDb.toFixed(1))
            if (!ok) root.fail(message)
            else if (peakDb < root.minPeakDb) root.fail(i18n.tr("Level too low (%1) — speak close to the microphone").arg(lv))
            else root.pass(lv + " — " + message)
        }
    }

    function run() {
        note(i18n.tr("Recording for 3 s… speak or tap the microphone"))
        backend.startMicTest(3000)
    }
}
