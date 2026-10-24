import QtQuick 2.12
import Lomiri.Components 1.3
import DeviceBackend 1.0
import ".."

// Mobile modem / SIM / network checks through oFono.
// mode: "modem" | "sim" | "network" | "data"
TestBase {
    id: root
    timeoutMs: 30000
    property string mode: "modem"

    Backend { id: backend }

    Timer { id: poll; interval: 2000; repeat: true; onTriggered: root.check() }

    // Returns { state: "pass" | "fail" | "skip" | "wait", msg }
    function evaluate() {
        var i = backend.simInfo()
        if (!i.ofono || !i.modem) return { state: "fail", msg: i.error }
        if (mode === "modem") {
            var txt = i.modemName + (i.imei ? ", IMEI " + i.imei : "")
            txt += i.online ? i18n.tr(" (online)") : i18n.tr(" (offline)")
            return { state: "pass", msg: txt }
        }
        if (!i.simPresent) return { state: "skip", msg: i18n.tr("No SIM card inserted") }
        var locked = i.pin && i.pin !== "none"
        if (mode === "sim") {
            if (locked) return { state: "fail", msg: i18n.tr("SIM locked (%1 required)").arg(i.pin) }
            return { state: "pass", msg: i.simOperator !== "" ? i18n.tr("SIM ready — %1").arg(i.simOperator) : i18n.tr("SIM ready") }
        }
        if (locked) return { state: "skip", msg: i18n.tr("SIM is locked") }
        if (mode === "network") {
            if (i.regStatus === "registered" || i.regStatus === "roaming")
                return { state: "pass", msg: i18n.tr("%1 (%2), signal %3%").arg(i.netName).arg(i.tech).arg(i.strength) }
            return { state: "wait", msg: i18n.tr("Not registered yet (%1)").arg(i.regStatus) }
        }
        if (i.attached) return { state: "pass", msg: i18n.tr("Mobile data attached") }
        return { state: "wait", msg: i18n.tr("Mobile data not attached (turn it on in Settings)") }
    }

    function check() {
        var r = evaluate()
        if (r.state === "wait") { note(r.msg); return }
        poll.stop()
        done(r.state, r.msg)
    }

    function run() { check(); if (status === "running") poll.start() }
    function cleanup() { poll.stop() }
}
