import QtQuick 2.12
import Lomiri.Components 1.3
import ".."

TestBase {
    id: root
    property var colors: ["#ff0000", "#00ff00", "#0000ff", "#ffffff", "#000000"]
    property int ci: 0

    Rectangle { anchors.fill: parent; color: root.colors[root.ci] }

    Timer {
        id: cycle
        interval: 1200
        repeat: true
        onTriggered: {
            if (root.ci < root.colors.length - 1) {
                root.ci++
            } else {
                cycle.stop()
                root.ask(i18n.tr("Were all the colors uniform (no dead pixels or stains)?"))
            }
        }
    }

    function run() { ci = 0; cycle.start() }
    function cleanup() { cycle.stop() }
}
