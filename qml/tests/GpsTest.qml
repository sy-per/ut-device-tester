import QtQuick 2.12
import Lomiri.Components 1.3
import QtPositioning 5.12
import ".."

// Waits for a first valid fix (clear sky recommended, can take > 1 min on a cold start).
TestBase {
    id: root
    timeoutMs: 120000

    PositionSource {
        id: ps
        active: false
        updateInterval: 1000
        preferredPositioningMethods: PositionSource.AllPositioningMethods
        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                var acc = position.horizontalAccuracyValid ? " ±" + Math.round(position.horizontalAccuracy) + " m" : ""
                root.pass(position.coordinate.latitude.toFixed(5) + ", " + position.coordinate.longitude.toFixed(5) + acc + " (" + ps.name + ")")
            }
        }
        onSourceErrorChanged: if (sourceError !== PositionSource.NoError) root.note(i18n.tr("GPS source error: ") + sourceError)
    }

    function run() {
        if (!ps.valid) { fail(i18n.tr("No position source (location service missing?)")); return }
        note(i18n.tr("Looking for a position (%1)…").arg(ps.name))
        ps.start()
    }
    function cleanup() { ps.stop() }
}
