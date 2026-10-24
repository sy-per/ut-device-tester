import QtQuick 2.12
import Lomiri.Components 1.3
import QtFeedback 5.0
import ".."

TestBase {
    id: root

    HapticsEffect {
        id: haptic
        attackIntensity: 0.0
        attackTime: 50
        intensity: 1.0
        duration: 800
        fadeTime: 50
        fadeIntensity: 0.0
    }

    function run() {
        note(i18n.tr("Vibrating…"))
        haptic.start()
        askTimer.start()
    }
    function cleanup() { haptic.stop(); askTimer.stop() }

    Timer {
        id: askTimer
        interval: 1200
        onTriggered: root.ask(i18n.tr("Did the phone vibrate?"))
    }
}
