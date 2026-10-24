import QtQuick 2.12
import Lomiri.Components 1.3
import QtMultimedia 5.12
import ".."

TestBase {
    id: root

    SoundEffect {
        id: tone
        source: Qt.resolvedUrl("../../assets/tone.wav")
        loops: 3
        volume: 1.0
        onStatusChanged: if (status === SoundEffect.Error) root.fail(i18n.tr("Audio playback failed"))
    }

    function run() {
        note(i18n.tr("Playing a tone…"))
        tone.play()
        askTimer.start()
    }
    function cleanup() { tone.stop(); askTimer.stop() }

    Timer {
        id: askTimer
        interval: 1500
        onTriggered: root.ask(i18n.tr("Do you hear a tone from the speaker?"))
    }
}
