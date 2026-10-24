import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.LocalStorage 2.0
import QtMultimedia 5.12
import Lomiri.Components 1.3
import DeviceBackend 1.0

MainView {
    id: mainView
    applicationName: "devicetester.jimmy"
    automaticOrientation: true
    width: units.gu(45)
    height: units.gu(80)

    // ---- State -------------------------------------------------------------
    property var tests: []
    property var queue: []
    property int qpos: -1
    property int current: -1
    property bool running: false
    property string phase: "intro"      // intro (instructions + Start) | run
    property int elapsed: 0
    property int rev: 0                 // bumped on every result change (for bindings)
    property string lastRun: ""
    readonly property var backend: backendObj   // C++ plugin (report saving, device info)
    property string toastText: ""
    property bool showOk: false
    property string openCat: ""          // category whose test list is shown

    readonly property var cats: [
        { id: "screen",  title: i18n.tr("Screen and touch"),       icon: "phone-smartphone-symbolic" },
        { id: "audio",   title: i18n.tr("Audio and vibration"),       icon: "audio-speakers-symbolic" },
        { id: "camera",  title: i18n.tr("Cameras and flashlight"),      icon: "camera-app-symbolic" },
        { id: "net",     title: i18n.tr("Network and location"),     icon: "network-wifi-symbolic" },
        { id: "sensors", title: i18n.tr("Sensors"),               icon: "location" },
        { id: "power",   title: i18n.tr("Battery and storage"),   icon: "battery-080" },
        { id: "adv",     title: i18n.tr("Advanced / SIM"),        icon: "simcard", guided: false },
        { id: "other",   title: i18n.tr("Other"),                 icon: "settings", guided: false }
    ]

    // Status colors (readable in light and dark themes)
    readonly property color okFg: "#2e8b45"
    readonly property color koFg: "#d0283c"
    readonly property color okBg: Qt.rgba(0.24, 0.70, 0.31, 0.18)
    readonly property color koBg: Qt.rgba(0.93, 0.19, 0.27, 0.16)
    readonly property color neutralBg: Qt.rgba(0.5, 0.5, 0.5, 0.16)

    Backend { id: backendObj }

    ListModel { id: results }           // title, status, detail, manual
    ListModel { id: summaryModel }      // title, status, detail

    // ---- Test definitions -----------------------------------------------
    // manual     : needs an action/confirmation => instruction screen before the test
    // fullscreen : the test draws on screen (colors, touch, camera)
    function buildTests() {
        var t = [
            { cat: "screen", title: i18n.tr("Screen – colors"), source: "tests/DisplayTest.qml", manual: true, fullscreen: true,
              intro: i18n.tr("The screen will show red, green, blue, white, then black. Look for dead pixels or stains, then answer.") },
            { cat: "screen", title: i18n.tr("Multi-touch"), source: "tests/TouchTest.qml", manual: true, fullscreen: true,
              intro: i18n.tr("Touch each of the 12 cells to turn them green. At some point, use 2 fingers at the same time.") },
            { cat: "screen", title: i18n.tr("Screen rotation"), source: "tests/RotationTest.qml", manual: true,
              intro: i18n.tr("Rotate the phone to landscape, then back to portrait. The screen orientation sensor must follow.") },
            { cat: "screen", title: i18n.tr("Volume buttons"), source: "tests/ButtonsTest.qml", manual: true,
              intro: i18n.tr("Press Volume up, then Volume down. If nothing reacts, the system is probably intercepting the keys: skip this step.") },
            { cat: "audio", title: i18n.tr("Vibration"), source: "tests/VibrationTest.qml", manual: true,
              intro: i18n.tr("Put your hand on the phone. It will vibrate for about a second.") },
            { cat: "audio", title: i18n.tr("Speaker"), source: "tests/SpeakerTest.qml", manual: true,
              intro: i18n.tr("Turn the volume up. A two-note tone will be played.") },
            { cat: "audio", title: i18n.tr("Microphone"), source: "tests/MicTest.qml", manual: true,
              intro: i18n.tr("As soon as you tap Start, speak or tap the bottom of the phone for 3 seconds.") },
            { cat: "power", title: i18n.tr("Battery"), source: "tests/BatteryTest.qml", manual: false,
              intro: i18n.tr("Reading the battery level, voltage and temperature.") },
            { cat: "power", title: i18n.tr("Storage (SQLite)"), source: "tests/StorageTest.qml", manual: false,
              intro: i18n.tr("Writes and reads back 200 rows in the local database.") },
            { cat: "net", title: i18n.tr("Internet (Wi-Fi / data)"), source: "tests/NetworkTest.qml", manual: false,
              intro: i18n.tr("Checks internet access. To test Wi-Fi alone, turn off mobile data.") },
            { cat: "net", title: i18n.tr("Wi-Fi (scan)"), source: "tests/WifiTest.qml", manual: false,
              intro: i18n.tr("Looks for visible Wi-Fi networks. Wi-Fi must be turned on.") },
            { cat: "net", title: i18n.tr("Bluetooth"), source: "tests/BluetoothTest.qml", manual: false,
              intro: i18n.tr("Turn Bluetooth on and put a discoverable device nearby.") },
            { cat: "net", title: i18n.tr("GPS"), source: "tests/GpsTest.qml", manual: false,
              intro: i18n.tr("Stand near a window or outside. It can take up to 2 minutes.") },
            { cat: "sensors", title: i18n.tr("Accelerometer"), source: "tests/SensorTest.qml", manual: false,
              intro: i18n.tr("Lay the phone flat and keep it still."),
              props: { sensorType: "QAccelerometer", fields: ["x", "y", "z"] } },
            { cat: "sensors", title: i18n.tr("Gyroscope"), source: "tests/SensorTest.qml", manual: false,
              intro: i18n.tr("Measuring rotation."),
              props: { sensorType: "QGyroscope", fields: ["x", "y", "z"] } },
            { cat: "sensors", title: i18n.tr("Magnetometer"), source: "tests/SensorTest.qml", manual: false,
              intro: i18n.tr("Keep the phone away from metal objects and magnets."),
              props: { sensorType: "QMagnetometer", fields: ["x", "y", "z"] } },
            { cat: "sensors", title: i18n.tr("Compass"), source: "tests/SensorTest.qml", manual: false,
              intro: i18n.tr("Reading the azimuth."),
              props: { sensorType: "QCompass", fields: ["azimuth"], optional: true } },
            { cat: "sensors", title: i18n.tr("Orientation"), source: "tests/SensorTest.qml", manual: false,
              intro: i18n.tr("Reading the device orientation."),
              props: { sensorType: "QOrientationSensor", fields: ["orientation"], optional: true } },
            { cat: "sensors", title: i18n.tr("Proximity sensor"), source: "tests/SensorTest.qml", manual: true,
              intro: i18n.tr("Wave your hand in front of the top of the screen (proximity sensor), then take it away."),
              props: { sensorType: "QProximitySensor", fields: ["near"], changeField: "near",
                       hint: i18n.tr("Wave your hand in front of the sensor") } },
            { cat: "sensors", title: i18n.tr("Light sensor"), source: "tests/SensorTest.qml", manual: true,
              intro: i18n.tr("Cover the light sensor (top of the screen) with your finger, then uncover it, ideally under a lamp."),
              props: { sensorType: "QLightSensor", fields: ["illuminance"], changeField: "illuminance",
                       hint: i18n.tr("Cover then uncover the sensor") } },
            { cat: "sensors", title: i18n.tr("Barometer"), source: "tests/SensorTest.qml", manual: false,
              intro: i18n.tr("Reading the atmospheric pressure (missing on many devices)."),
              props: { sensorType: "QPressureSensor", fields: ["pressure"], optional: true } }
        ]
        t.push(
            { cat: "adv", title: i18n.tr("Modem"), source: "tests/SimTest.qml", manual: false, props: { mode: "modem" },
              intro: i18n.tr("Checks that the mobile modem is detected by oFono.") },
            { cat: "adv", title: i18n.tr("SIM card"), source: "tests/SimTest.qml", manual: false, props: { mode: "sim" },
              intro: i18n.tr("Checks that a SIM card is inserted and unlocked.") },
            { cat: "adv", title: i18n.tr("Mobile network"), source: "tests/SimTest.qml", manual: false, props: { mode: "network" },
              intro: i18n.tr("Checks the registration on the operator network and the signal strength.") },
            { cat: "adv", title: i18n.tr("Mobile data"), source: "tests/SimTest.qml", manual: false, props: { mode: "data" },
              intro: i18n.tr("Checks that mobile data is attached. Turn it on in Settings first.") },
            { cat: "other", title: i18n.tr("Charger and USB"), source: "tests/ChargerTest.qml", manual: true,
              intro: i18n.tr("Plug in or unplug the charging cable (USB or wall charger). The change must be detected.") },
            { cat: "other", title: i18n.tr("Memory and storage"), source: "tests/MemoryTest.qml", manual: false,
              intro: i18n.tr("Reads the free RAM and the free storage space.") },
            { cat: "other", title: i18n.tr("Headset jack"), source: "tests/HeadsetTest.qml", manual: true,
              intro: i18n.tr("Plug a headset or headphones into the 3.5 mm jack. If one is already plugged in, unplug it first.") },
            { cat: "other", title: i18n.tr("Wi-Fi speed"), source: "tests/WifiSpeedTest.qml", manual: false,
              intro: i18n.tr("Downloads a 5 MB file to measure the speed of the active connection.") },
            { cat: "other", title: i18n.tr("Device information"), source: "tests/DeviceInfoTest.qml", manual: false,
              intro: i18n.tr("Collects the model, system version, kernel and CPU information.") }
        )
        var cams = QtMultimedia.availableCameras
        var posName = { 1: i18n.tr("rear"), 2: i18n.tr("front") }
        if (cams.length === 0) {
            t.push({ cat: "camera", title: i18n.tr("Camera"), source: "tests/CameraTest.qml", manual: false, fullscreen: true,
                     intro: i18n.tr("No camera detected."), props: { cameraIndex: -1 } })
        } else {
            for (var i = 0; i < cams.length; i++)
                t.push({ cat: "camera", title: i18n.tr("%1 camera").arg(posName[cams[i].position] || i), source: "tests/CameraTest.qml",
                         manual: true, fullscreen: true, props: { cameraIndex: i },
                         intro: i18n.tr("The camera opens and takes a photo by itself. On some devices the camera driver can crash the app: results already obtained are kept.") })
            t.push({ cat: "camera", title: i18n.tr("Flashlight"), source: "tests/TorchTest.qml", manual: true,
                     intro: i18n.tr("The flashlight will turn on at the back of the phone. Look at it.") })
        }
        tests = t
        results.clear()
        for (var k = 0; k < t.length; k++)
            results.append({ title: t[k].title, status: "idle", detail: "", manual: t[k].manual })
    }

    // ---- Selection / counters -----------------------------------------------
    // Categories flagged guided:false (Advanced, Other) are only reachable from their own list
    function inGuided(catId) {
        for (var i = 0; i < cats.length; i++) if (cats[i].id === catId) return cats[i].guided !== false
        return true
    }
    function allIndexes(autoOnly) {
        var q = []
        for (var i = 0; i < tests.length; i++)
            if (inGuided(tests[i].cat) && (!autoOnly || !tests[i].manual)) q.push(i)
        return q
    }
    function catIndexes(id) {
        var q = []
        for (var i = 0; i < tests.length; i++) if (tests[i].cat === id) q.push(i)
        return q
    }
    function failedIndexes() {
        var q = []
        for (var i = 0; i < results.count; i++) if (results.get(i).status === "fail") q.push(i)
        return q
    }
    function catName(id) {
        for (var i = 0; i < cats.length; i++) if (cats[i].id === id) return cats[i].title
        return ""
    }
    function catIcon(id) {
        for (var i = 0; i < cats.length; i++) if (cats[i].id === id) return cats[i].icon
        return "info"
    }
    function counts() {
        var c = { pass: 0, fail: 0, skip: 0, idle: 0 }
        for (var i = 0; i < results.count; i++) {
            var s = results.get(i).status
            c[s === "running" ? "idle" : s]++
        }
        return c
    }
    // { text, kind: idle|ok|ko } for a category chip
    function chipFor(ids) {
        var p = 0, f = 0, done = 0
        for (var i = 0; i < ids.length; i++) {
            var s = results.get(ids[i]).status
            if (s === "pass") p++
            else if (s === "fail") f++
            if (s !== "idle" && s !== "running") done++
        }
        if (done === 0) return { text: i18n.tr("to do"), kind: "idle" }
        return { text: p + "/" + ids.length, kind: f > 0 ? "ko" : (p === ids.length ? "ok" : "idle") }
    }

    // ---- Run queue -----------------------------------------------------------
    function startQueue(q) {
        if (running || q.length === 0) return
        queue = q
        qpos = -1
        running = true
        resultsPanel.visible = false
        for (var i = 0; i < q.length; i++) {
            results.setProperty(q[i], "status", "idle")
            results.setProperty(q[i], "detail", "")
        }
        rev++
        nextTest()
    }

    function nextTest() {
        loader.source = ""
        qpos++
        if (qpos >= queue.length) { finishRun(); return }
        current = queue[qpos]
        results.setProperty(current, "status", "running")
        results.setProperty(current, "detail", "")
        saveState()     // si l'app plante pendant ce test, on saura lequel
        if (tests[current].manual) phase = "intro"
        else startCurrent()
    }

    function startCurrent() {
        elapsed = 0
        phase = "run"
        var t = tests[current]
        loader.setSource(t.source, t.props || {})
    }

    function skipCurrent(msg) {
        if (phase === "intro") record(current, "skip", msg)
        else if (loader.item) loader.item.skip(msg)
        else record(current, "skip", msg)
    }

    function record(i, status, detail) {
        results.setProperty(i, "status", status)
        results.setProperty(i, "detail", detail)
        rev++
        saveState()
        settle.restart()    // let the hardware (camera...) be released before the next test
    }

    function abortRun() {
        settle.stop()
        if (loader.item) loader.item.stop()
        loader.source = ""
        if (current >= 0 && results.get(current).status === "running") results.setProperty(current, "status", "idle")
        running = false
        queue = []
        rev++
        saveState()
    }

    function finishRun() {
        var n = queue.length
        var last = n === 1 ? queue[0] : -1
        running = false
        queue = []
        lastRun = new Date().toLocaleString(Qt.locale(), "d MMM, HH:mm")
        rev++
        saveState()
        if (n > 1) openSummary()
        else if (last >= 0) {
            var r = results.get(last)
            toast((r.status === "pass" ? i18n.tr("OK") : r.status === "fail" ? i18n.tr("Failed") : i18n.tr("Skipped")) + " — " + r.title
                  + (r.detail ? " : " + r.detail : ""))
        }
    }

    // ---- Rapport -------------------------------------------------------------
    function openSummary() {
        summaryModel.clear()
        for (var i = 0; i < results.count; i++) {
            var r = results.get(i)
            if (r.status === "idle") continue
            if (r.status === "pass" && !showOk) continue
            summaryModel.append({ title: r.title, status: r.status, detail: r.detail })
        }
        resultsPanel.visible = true
    }

    function reportText() {
        var c = counts()
        var lines = []
        lines.push("Device Tester — " + new Date().toLocaleString())
        lines.push("OS: " + Qt.platform.os + " | " + i18n.tr("screen") + " " + Screen.width + "x" + Screen.height
                   + " @" + Screen.devicePixelRatio.toFixed(2) + "x | gu=" + units.gridUnit)
        lines.push(i18n.tr("Result: %1 passed, %2 failed, %3 skipped, %4 not run").arg(c.pass).arg(c.fail).arg(c.skip).arg(c.idle))
        lines.push("")
        var tag = { pass: "[OK]  ", fail: "[KO]  ", skip: "[--]  ", idle: "[ ]   ", running: "[..]  " }
        for (var i = 0; i < results.count; i++) {
            var r = results.get(i)
            lines.push(tag[r.status] + r.title + (r.detail ? " — " + r.detail : ""))
        }
        return lines.join("\n")
    }

    function saveReport() {
        if (!backend) { toast(i18n.tr("Saving unavailable (plugin missing)")); return }
        var path = backend.saveReport(reportText())
        toast(path !== "" ? i18n.tr("Report saved: ") + path : i18n.tr("Could not save the report"))
    }

    function toast(msg) { toastText = msg; toastTimer.restart() }

    // ---- Persistance du dernier passage ----------------------------------------
    function db() { return LocalStorage.openDatabaseSync("devicetester", "1.0", "Device Tester", 1000000) }

    function saveState() {
        try {
            var arr = []
            for (var i = 0; i < results.count; i++) {
                var r = results.get(i)
                arr.push({ t: r.title, s: r.status, d: r.detail })
            }
            var blob = JSON.stringify({ date: lastRun, r: arr })
            db().transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT PRIMARY KEY, v TEXT)")
                tx.executeSql("INSERT OR REPLACE INTO kv(k, v) VALUES('last', ?)", [blob])
            })
        } catch (e) {}
    }

    function loadState() {
        try {
            db().transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS kv(k TEXT PRIMARY KEY, v TEXT)")
                var rs = tx.executeSql("SELECT v FROM kv WHERE k = 'last'")
                if (rs.rows.length === 0) return
                var o = JSON.parse(rs.rows.item(0).v)
                lastRun = o.date || ""
                for (var j = 0; j < o.r.length; j++)
                    for (var i = 0; i < results.count; i++)
                        if (results.get(i).title === o.r[j].t) {
                            var crashed = o.r[j].s === "running"
                            results.setProperty(i, "status", crashed ? "fail" : o.r[j].s)
                            results.setProperty(i, "detail", crashed ? i18n.tr("The app crashed during this test") : o.r[j].d)
                        }
            })
        } catch (e) {}
        rev++
    }

    Component.onCompleted: {
        buildTests()
        loadState()
    }

    Timer { id: settle; interval: 700; onTriggered: mainView.nextTest() }
    Timer { id: toastTimer; interval: 4000; onTriggered: mainView.toastText = "" }
    Timer {
        interval: 1000; repeat: true
        running: mainView.running && mainView.phase === "run"
        onTriggered: mainView.elapsed++
    }

    // =========================================================================
    // Accueil
    // =========================================================================
    Page {
        id: home
        anchors.fill: parent

        header: PageHeader {
            id: homeHeader
            title: i18n.tr("Device Tester")
            subtitle: "Ubuntu Touch · " + Screen.width + "×" + Screen.height
            trailingActionBar.actions: [
                Action {
                    iconName: "document-preview"
                    text: i18n.tr("Report")
                    onTriggered: mainView.openSummary()
                }
            ]
        }

        Flickable {
            anchors { top: homeHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            contentHeight: homeCol.height + units.gu(4)
            clip: true

            Column {
                id: homeCol
                width: parent.width
                spacing: units.gu(1.5)
                topPadding: units.gu(2)

                ActionButton {
                    anchors { left: parent.left; right: parent.right; margins: units.gu(2) }
                    text: i18n.tr("Start the guided assistant")
                    iconName: "media-playback-start"
                    onClicked: mainView.startQueue(mainView.allIndexes(false))
                }
                Label {
                    anchors { left: parent.left; right: parent.right; margins: units.gu(2) }
                    text: mainView.lastRun !== "" ? i18n.tr("Last run: ") + mainView.lastRun : i18n.tr("No run recorded yet")
                    textSize: Label.Small
                    color: theme.palette.normal.backgroundSecondaryText
                }

                Repeater {
                    model: mainView.cats
                    delegate: ListItem {
                        id: catItem
                        readonly property var ids: mainView.catIndexes(modelData.id)
                        readonly property var chip: { mainView.rev; return mainView.chipFor(ids) }
                        height: units.gu(7)
                        divider.visible: true
                        onClicked: mainView.openCat = modelData.id
                        ListItemLayout {
                            title.text: modelData.title
                            subtitle.text: i18n.tr("%1 test(s)").arg(catItem.ids.length)
                            Icon {
                                SlotsLayout.position: SlotsLayout.Leading
                                width: units.gu(3); height: width
                                name: modelData.icon
                            }
                            Rectangle {
                                SlotsLayout.position: SlotsLayout.Trailing
                                width: chipLabel.width + units.gu(2)
                                height: units.gu(3)
                                radius: units.gu(1)
                                color: catItem.chip.kind === "ok" ? mainView.okBg : catItem.chip.kind === "ko" ? mainView.koBg : mainView.neutralBg
                                Label {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: catItem.chip.text
                                    textSize: Label.Small
                                    color: catItem.chip.kind === "ok" ? mainView.okFg : catItem.chip.kind === "ko" ? mainView.koFg : theme.palette.normal.backgroundSecondaryText
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Test list of a category (pick a single test)
    // =========================================================================
    Rectangle {
        id: catPanel
        anchors.fill: parent
        visible: mainView.openCat !== ""
        color: theme.palette.normal.background
        z: 40
        readonly property var ids: mainView.openCat !== "" ? mainView.catIndexes(mainView.openCat) : []

        Item {
            id: catHead
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: units.gu(7)
            Item {
                id: backBtn
                anchors { left: parent.left; leftMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                width: units.gu(5); height: units.gu(5)
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3); height: width
                    name: "back"
                    color: theme.palette.normal.backgroundText
                }
                MouseArea { anchors.fill: parent; onClicked: mainView.openCat = "" }
            }
            Label {
                anchors { left: backBtn.right; leftMargin: units.gu(1); right: parent.right; verticalCenter: parent.verticalCenter }
                text: mainView.catName(mainView.openCat)
                textSize: Label.Large
                elide: Text.ElideRight
            }
        }

        ActionButton {
            id: catAll
            anchors { top: catHead.bottom; left: parent.left; right: parent.right; margins: units.gu(2) }
            text: i18n.tr("Run the whole category")
            iconName: "media-playback-start"
            onClicked: mainView.startQueue(catPanel.ids)
        }

        Label {
            id: catHint
            anchors { top: catAll.bottom; topMargin: units.gu(1.5); left: parent.left; right: parent.right; leftMargin: units.gu(2) }
            text: i18n.tr("Or tap a test to run it on its own")
            textSize: Label.Small
            color: theme.palette.normal.backgroundSecondaryText
        }

        ListView {
            anchors { top: catHint.bottom; topMargin: units.gu(1); left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true
            model: catPanel.ids
            delegate: ListItem {
                id: testItem
                readonly property var r: { mainView.rev; return results.get(modelData) }
                height: tl.height + divider.height
                onClicked: mainView.startQueue([modelData])
                ListItemLayout {
                    id: tl
                    title.text: testItem.r.title
                    subtitle.text: testItem.r.detail !== "" ? testItem.r.detail
                                   : (testItem.r.manual ? i18n.tr("Interaction required") : i18n.tr("Automatic"))
                    subtitle.maximumLineCount: 3
                    Rectangle {
                        SlotsLayout.position: SlotsLayout.Leading
                        width: units.gu(1.6); height: width; radius: width / 2
                        color: testItem.r.status === "pass" ? mainView.okFg
                             : testItem.r.status === "fail" ? mainView.koFg
                             : testItem.r.status === "skip" ? theme.palette.normal.backgroundSecondaryText
                             : mainView.neutralBg
                    }
                    Icon {
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2.5); height: width
                        name: "media-playback-start"
                        color: theme.palette.normal.backgroundSecondaryText
                    }
                }
            }
        }
    }

    // =========================================================================
    // Assistant (full screen)
    // =========================================================================
    Rectangle {
        id: stage
        anchors.fill: parent
        visible: mainView.running
        color: theme.palette.normal.background
        z: 50

        readonly property var t: mainView.current >= 0 && mainView.current < mainView.tests.length ? mainView.tests[mainView.current] : null
        readonly property bool full: t ? !!t.fullscreen : false
        readonly property bool showTest: full && mainView.phase === "run"
        readonly property var item: loader.item
        readonly property string question: item ? item.question : ""

        // Top bar: quit + progress
        Rectangle {
            id: topBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: units.gu(8)
            color: stage.showTest ? "#d9000000" : "transparent"
            z: 30
            Item {
                id: closeBtn
                anchors { left: parent.left; leftMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                width: units.gu(5); height: units.gu(5)
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3); height: width
                    name: "close"
                    color: stage.showTest ? "white" : theme.palette.normal.backgroundText
                }
                MouseArea { anchors.fill: parent; onClicked: mainView.abortRun() }
            }
            Column {
                anchors { left: closeBtn.right; leftMargin: units.gu(1.5); right: stageSkip.left; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                spacing: units.gu(0.8)
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    textSize: Label.Small
                    color: stage.showTest ? "white" : theme.palette.normal.backgroundSecondaryText
                    text: i18n.tr("Step %1 of %2").arg(mainView.qpos + 1).arg(mainView.queue.length)
                          + (stage.t ? " · " + mainView.catName(stage.t.cat) : "")
                }
                Rectangle {
                    width: parent.width; height: units.gu(0.7); radius: height / 2
                    color: mainView.neutralBg
                    Rectangle {
                        height: parent.height; radius: height / 2
                        color: theme.palette.normal.focus
                        width: mainView.queue.length > 0 ? parent.width * (mainView.qpos + 1) / mainView.queue.length : 0
                    }
                }
            }
            Label {
                id: stageSkip
                anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                text: i18n.tr("Skip")
                color: stage.showTest ? "white" : theme.palette.normal.backgroundSecondaryText
                MouseArea {
                    anchors { fill: parent; margins: -units.gu(1.5) }
                    onClicked: mainView.skipCurrent(i18n.tr("Skipped by the user"))
                }
            }
        }

        // Test area (full screen for visual tests, 1 px otherwise: keyboard focus is kept)
        Loader {
            id: loader
            anchors { top: stage.showTest ? stage.top : topBar.bottom; left: parent.left; right: parent.right }
            height: stage.showTest ? stage.height : 1
            opacity: stage.showTest ? 1 : 0
            z: stage.showTest ? 10 : 0
            onStatusChanged: {
                if (status === Loader.Error)
                    mainView.record(mainView.current, "fail", i18n.tr("QML module not available on this device"))
                else if (status === Loader.Ready) {
                    item.showBar = stage.full
                    item.start()
                }
            }
        }

        Connections {
            target: loader.item
            ignoreUnknownSignals: true
            onFinished: mainView.record(mainView.current, loader.item.status, loader.item.detail)
            onDetailChanged: if (mainView.current >= 0) results.setProperty(mainView.current, "detail", loader.item.detail)
        }

        // Instruction / status card (non-visual tests and instruction screen)
        Item {
            id: card
            anchors { top: topBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            visible: !stage.showTest
            z: 20

            Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(3) }
                spacing: units.gu(2.5)

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(12); height: width; radius: width / 2
                    color: mainView.neutralBg
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(6); height: width
                        name: stage.t ? mainView.catIcon(stage.t.cat) : "info"
                    }
                }
                Label {
                    width: parent.width
                    text: stage.t ? stage.t.title : ""
                    textSize: Label.XLarge
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Label {
                    width: parent.width
                    text: stage.t && stage.t.intro ? stage.t.intro : ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: theme.palette.normal.backgroundSecondaryText
                }

                // Instruction screen: Start / Skip
                Column {
                    width: parent.width
                    spacing: units.gu(1.5)
                    visible: mainView.phase === "intro"
                    Button {
                        anchors { left: parent.left; right: parent.right }
                        height: units.gu(6)
                        text: i18n.tr("Start")
                        color: theme.palette.normal.positive
                        onClicked: mainView.startCurrent()
                    }
                    Button {
                        anchors { left: parent.left; right: parent.right }
                        text: i18n.tr("Skip this step")
                        onClicked: mainView.skipCurrent(i18n.tr("Skipped by the user"))
                    }
                }

                // Running test: live status
                Rectangle {
                    width: parent.width
                    height: runCol.height + units.gu(3)
                    radius: units.gu(1.5)
                    color: mainView.neutralBg
                    visible: mainView.phase === "run" && stage.question === ""
                    Column {
                        id: runCol
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(1.5) }
                        spacing: units.gu(1)
                        Row {
                            spacing: units.gu(1.5)
                            ActivityIndicator { running: parent.visible; anchors.verticalCenter: parent.verticalCenter }
                            Label {
                                width: runCol.width - units.gu(5)
                                text: stage.item && stage.item.detail !== "" ? stage.item.detail : i18n.tr("Test in progress…")
                                wrapMode: Text.WordWrap
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Label {
                            visible: stage.item && stage.item.timeoutMs > 0
                            textSize: Label.Small
                            color: theme.palette.normal.backgroundSecondaryText
                            function mmss(s) { return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }
                            text: stage.item ? i18n.tr("%1 elapsed of %2").arg(mmss(mainView.elapsed)).arg(mmss(Math.round(stage.item.timeoutMs / 1000))) : ""
                        }
                    }
                }

                // Question asked by the test: Yes / No
                Rectangle {
                    width: parent.width
                    height: qCol.height + units.gu(3)
                    radius: units.gu(1.5)
                    color: mainView.neutralBg
                    visible: mainView.phase === "run" && stage.question !== "" && !stage.full
                    Column {
                        id: qCol
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(1.5) }
                        spacing: units.gu(2)
                        Label {
                            width: parent.width
                            text: stage.question
                            textSize: Label.Large
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        Row {
                            spacing: units.gu(2)
                            anchors.horizontalCenter: parent.horizontalCenter
                            Button {
                                width: (qCol.width - units.gu(2)) / 2; height: units.gu(6)
                                text: i18n.tr("Yes")
                                color: theme.palette.normal.positive
                                onClicked: if (stage.item) stage.item.pass(i18n.tr("Confirmed by the user"))
                            }
                            Button {
                                width: (qCol.width - units.gu(2)) / 2; height: units.gu(6)
                                text: i18n.tr("No")
                                color: theme.palette.normal.negative
                                onClicked: if (stage.item) stage.item.fail(i18n.tr("Rejected by the user"))
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Summary
    // =========================================================================
    Rectangle {
        id: resultsPanel
        anchors.fill: parent
        visible: false
        z: 100
        color: theme.palette.normal.background

        property var c: ({ pass: 0, fail: 0, skip: 0, idle: 0 })
        Connections { target: mainView; onRevChanged: resultsPanel.c = mainView.counts() }

        Column {
            id: sumHead
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: units.gu(3) }
            spacing: units.gu(1)
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Result")
                color: theme.palette.normal.backgroundSecondaryText
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: resultsPanel.c.pass + " / " + (resultsPanel.c.pass + resultsPanel.c.fail + resultsPanel.c.skip)
                font.pixelSize: units.gu(6)
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: units.gu(1)
                Repeater {
                    model: [
                        { t: i18n.tr("%1 passed").arg(resultsPanel.c.pass), bg: mainView.okBg, fg: mainView.okFg },
                        { t: i18n.tr("%1 failed").arg(resultsPanel.c.fail), bg: mainView.koBg, fg: mainView.koFg },
                        { t: i18n.tr("%1 skipped").arg(resultsPanel.c.skip), bg: mainView.neutralBg, fg: theme.palette.normal.backgroundSecondaryText }
                    ]
                    delegate: Rectangle {
                        width: pl.width + units.gu(2); height: units.gu(3); radius: units.gu(1); color: modelData.bg
                        Label { id: pl; anchors.centerIn: parent; text: modelData.t; textSize: Label.Small; color: modelData.fg }
                    }
                }
            }
        }

        ListView {
            id: sumList
            anchors { top: sumHead.bottom; topMargin: units.gu(2); left: parent.left; right: parent.right; bottom: sumButtons.top }
            clip: true
            model: summaryModel
            delegate: ListItem {
                height: sl.height + divider.height
                ListItemLayout {
                    id: sl
                    title.text: model.title
                    subtitle.text: model.detail
                    subtitle.maximumLineCount: 3
                    Icon {
                        SlotsLayout.position: SlotsLayout.Leading
                        width: units.gu(2.5); height: width
                        name: model.status === "pass" ? "tick" : model.status === "fail" ? "close" : "media-skip-forward"
                        color: model.status === "pass" ? mainView.okFg : model.status === "fail" ? mainView.koFg : theme.palette.normal.backgroundSecondaryText
                    }
                }
            }
            footer: ListItem {
                height: units.gu(6)
                onClicked: { mainView.showOk = !mainView.showOk; mainView.openSummary() }
                ListItemLayout {
                    title.text: mainView.showOk ? i18n.tr("Hide passed tests") : i18n.tr("Show the %1 passed tests").arg(resultsPanel.c.pass)
                }
            }
        }

        Column {
            id: sumButtons
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: units.gu(2) }
            spacing: units.gu(1.2)
            Button {
                anchors { left: parent.left; right: parent.right }
                height: units.gu(6)
                visible: resultsPanel.c.fail > 0
                text: i18n.tr("Rerun failed tests")
                iconName: "reload"
                color: theme.palette.normal.positive
                onClicked: mainView.startQueue(mainView.failedIndexes())
            }
            Row {
                spacing: units.gu(1.2)
                Button {
                    width: (sumButtons.width - units.gu(1.2)) / 2
                    text: i18n.tr("Copy")
                    iconName: "edit-copy"
                    onClicked: { Clipboard.push(mainView.reportText()); mainView.toast(i18n.tr("Report copied")) }
                }
                Button {
                    width: (sumButtons.width - units.gu(1.2)) / 2
                    text: i18n.tr("Save")
                    iconName: "save"
                    onClicked: mainView.saveReport()
                }
            }
            Button {
                anchors { left: parent.left; right: parent.right }
                text: i18n.tr("Close")
                onClicked: resultsPanel.visible = false
            }
        }
    }

    // ---- Message temporaire -------------------------------------------------------
    Rectangle {
        z: 200
        visible: mainView.toastText !== ""
        anchors { bottom: parent.bottom; bottomMargin: units.gu(3); horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width - units.gu(4), toastLabel.implicitWidth + units.gu(4))
        height: toastLabel.implicitHeight + units.gu(2)
        radius: units.gu(1.5)
        color: "#e6222222"
        Label {
            id: toastLabel
            anchors { fill: parent; margins: units.gu(1) }
            text: mainView.toastText
            color: "white"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            textSize: Label.Small
        }
    }
}
