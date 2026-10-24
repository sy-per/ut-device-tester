import QtQuick 2.12
import Lomiri.Components 1.3
import ".."

// Touch the 12 cells (at least once with 2 fingers at the same time).
TestBase {
    id: root
    timeoutMs: 60000
    property var hits: []
    property int maxFingers: 0
    readonly property int cols: 3
    readonly property int rows: 4

    Grid {
        anchors.fill: parent
        columns: root.cols
        Repeater {
            model: root.cols * root.rows
            Rectangle {
                width: root.width / root.cols
                height: root.height / root.rows
                color: root.hits[index] ? "#3eb34f" : "#444"
                border.color: "#222"
            }
        }
    }

    MultiPointTouchArea {
        anchors.fill: parent
        maximumTouchPoints: 10
        onTouchUpdated: {
            var h = root.hits.slice()
            var n = 0
            for (var i = 0; i < touchPoints.length; i++) {
                var tp = touchPoints[i]
                if (!tp.pressed) continue
                n++
                var cx = Math.min(root.cols - 1, Math.max(0, Math.floor(tp.x / (width / root.cols))))
                var cy = Math.min(root.rows - 1, Math.max(0, Math.floor(tp.y / (height / root.rows))))
                h[cy * root.cols + cx] = true
            }
            root.maxFingers = Math.max(root.maxFingers, n)
            root.hits = h
            var total = 0
            for (var k = 0; k < root.cols * root.rows; k++) if (h[k]) total++
            root.note(i18n.tr("%1/%2 cells, %3 finger(s) max").arg(total).arg(root.cols * root.rows).arg(root.maxFingers))
            if (total === root.cols * root.rows && root.maxFingers >= 2)
                root.pass(i18n.tr("All zones OK, multi-touch with %1 fingers").arg(root.maxFingers))
        }
    }

    function run() { note(i18n.tr("Touch every cell, using 2 fingers at some point")) }
}
