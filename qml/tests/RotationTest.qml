import QtQuick 2.12
import Lomiri.Components 1.3
import ".."

// Rotate the phone to landscape and back to portrait: both must be reported by the orientation sensor.
TestBase {
    id: root
    timeoutMs: 60000
    property var seen: ({})
    property var sensor: null

    function orientationName(o) {
        switch (o) {
        case 1: return i18n.tr("Portrait")
        case 2: return i18n.tr("Portrait (upside down)")
        case 3: return i18n.tr("Landscape (left)")
        case 4: return i18n.tr("Landscape (right)")
        case 5: return i18n.tr("Face up")
        case 6: return i18n.tr("Face down")
        }
        return i18n.tr("Unknown")
    }

    function handle() {
        var o = sensor.reading.orientation
        seen[o] = true
        var portrait = seen[1] || seen[2]
        var landscape = seen[3] || seen[4]
        note(i18n.tr("Now: %1 — portrait %2, landscape %3").arg(orientationName(o)).arg(portrait ? "✓" : "…").arg(landscape ? "✓" : "…"))
        if (portrait && landscape) pass(i18n.tr("Portrait and landscape detected"))
    }

    function run() {
        try {
            sensor = Qt.createQmlObject('import QtQuick 2.12; import QtSensors 5.12; OrientationSensor { active: false }', root)
            sensor.readingChanged.connect(handle)
        } catch (e) {
            sensor = null
        }
        if (!sensor || !sensor.start() || !sensor.connectedToBackend) { fail(i18n.tr("Orientation sensor not available")); return }
        note(i18n.tr("Rotate the phone to landscape, then back to portrait"))
    }
    function cleanup() { if (sensor) sensor.stop() }
}
