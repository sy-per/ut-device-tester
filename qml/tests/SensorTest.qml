import QtQuick 2.12
import Lomiri.Components 1.3
import QtSensors 5.12
import ".."

// Generic QtSensors sensor test.
//  sensorType  : "QAccelerometer", "QGyroscope"...
//  fields      : reading properties to display
//  changeField : when set, the test requires this value to change (e.g. proximity, light)
//  optional    : missing sensor => "skipped" instead of failed
TestBase {
    id: root
    timeoutMs: 10000
    property string sensorType: "QAccelerometer"
    property var fields: ["x", "y", "z"]
    property string changeField: ""
    property string hint: ""
    property bool optional: false
    onHintChanged: if (hint !== "") timeoutMs = 20000
    property var firstValue: undefined

    // The generic Sensor type cannot be instantiated in QML: create the concrete element (Accelerometer...)
    readonly property var qmlTypes: ({
        QAccelerometer: "Accelerometer", QGyroscope: "Gyroscope", QMagnetometer: "Magnetometer",
        QCompass: "Compass", QOrientationSensor: "OrientationSensor", QProximitySensor: "ProximitySensor",
        QLightSensor: "LightSensor", QPressureSensor: "PressureSensor"
    })
    property var sensor: null

    function fmt(r) {
        var out = []
        for (var i = 0; i < fields.length; i++) {
            var v = r[fields[i]]
            out.push(fields[i] + "=" + (typeof v === "number" ? v.toFixed(3) : v))
        }
        return out.join("  ")
    }

    function handle(r) {
        if (!r) return
        var txt = fmt(r)
        if (changeField !== "") {
            var v = r[changeField]
            if (firstValue === undefined) { firstValue = v; note(txt + " — " + hint); return }
            if (v !== firstValue) { pass(txt); return }
            note(txt + " — " + hint)
            return
        }
        // Plausibility checks
        var mag = Math.sqrt((r.x || 0) * (r.x || 0) + (r.y || 0) * (r.y || 0) + (r.z || 0) * (r.z || 0))
        if (sensorType === "QAccelerometer") {
            if (mag > 7 && mag < 12.5) pass(txt + i18n.tr("  (|g|=%1)").arg(mag.toFixed(2)))
            else note(txt + i18n.tr("  |g|=%1 out of range").arg(mag.toFixed(2)))
        } else if (sensorType === "QMagnetometer") {
            if (mag > 1e-5 && mag < 1.5e-4) pass(txt)
            else note(txt + i18n.tr("  field out of range — calibrate (draw an 8 in the air)"))
        } else {
            pass(txt)
        }
    }

    function run() {
        var el = qmlTypes[sensorType]
        try {
            sensor = Qt.createQmlObject('import QtQuick 2.12; import QtSensors 5.12; ' + el + ' { active: false }', root)
            sensor.readingChanged.connect(function() { root.handle(sensor.reading) })
        } catch (e) {
            sensor = null
        }
        var started = sensor ? sensor.start() : false
        if (!started || !sensor.connectedToBackend) {
            if (optional) skip(i18n.tr("Sensor not present on this device"))
            else fail(i18n.tr("Sensor missing / backend unavailable (%1)").arg(sensorType))
            return
        }
        note(hint)
    }
    function cleanup() { if (sensor) sensor.stop() }
}
