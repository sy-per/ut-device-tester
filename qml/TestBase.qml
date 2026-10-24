import QtQuick 2.12
import Lomiri.Components 1.3

// Base of all tests. A child test overrides run() (and cleanup()), then
// appelle pass() / fail() / skip(), et note() pour afficher une info en cours.
Item {
    id: base

    property string status: "idle"      // idle | running | pass | fail | skip
    property string detail: ""
    property int timeoutMs: 10000
    property string question: ""        // when not empty, question to ask the user
    property bool showBar: true         // false: the host (assistant) shows Yes/No itself

    signal finished()

    function start() {
        status = "running"
        detail = ""
        question = ""
        timeoutTimer.restart()
        startTimer.start()
    }
    function stop() {
        timeoutTimer.stop()
        startTimer.stop()
        cleanup()
    }
    function run() {}
    function cleanup() {}

    function note(msg) { if (status === "running") detail = msg }
    function pass(msg) { done("pass", msg) }
    function fail(msg) { done("fail", msg) }
    function skip(msg) { done("skip", msg) }
    function ask(q) {
        timeoutTimer.interval = Math.max(timeoutTimer.interval, 60000)
        timeoutTimer.restart()
        question = q
    }
    function done(s, msg) {
        if (status !== "running") return
        timeoutTimer.stop()
        question = ""
        if (msg !== undefined && msg !== "") detail = msg
        status = s
        cleanup()
        finished()
    }

    Timer { id: startTimer; interval: 150; onTriggered: base.run() }
    Timer {
        id: timeoutTimer
        interval: base.timeoutMs
        onTriggered: base.done("fail", base.detail !== "" ? i18n.tr("Timed out — ") + base.detail : i18n.tr("Timed out"))
    }

    Rectangle {
        id: bar
        z: 1000
        visible: base.showBar && base.question !== ""
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: col.height + units.gu(3)
        color: "#cc000000"
        Column {
            id: col
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(2) }
            spacing: units.gu(1.5)
            Label {
                width: parent.width
                text: base.question
                color: "white"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: units.gu(2)
                Button { text: i18n.tr("Yes"); color: theme.palette.normal.positive; onClicked: base.pass(i18n.tr("Confirmed by the user")) }
                Button { text: i18n.tr("No"); color: theme.palette.normal.negative; onClicked: base.fail(i18n.tr("Rejected by the user")) }
            }
        }
    }
}
