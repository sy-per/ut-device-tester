import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.LocalStorage 2.0
import ".."

// Write / read back / delete in the app's local SQLite database.
TestBase {
    id: root

    function run() {
        try {
            var t0 = Date.now()
            var db = LocalStorage.openDatabaseSync("devicetester", "1.0", "Test stockage", 1000000)
            var token = "dt-" + Math.random().toString(36).slice(2)
            var readBack = ""
            var n = 200
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS probe(id INTEGER PRIMARY KEY, v TEXT)")
                for (var i = 0; i < n; i++) tx.executeSql("INSERT INTO probe(v) VALUES(?)", [token + i])
                var rs = tx.executeSql("SELECT v FROM probe WHERE v = ?", [token + (n - 1)])
                if (rs.rows.length === 1) readBack = rs.rows.item(0).v
                tx.executeSql("DELETE FROM probe")
            })
            var ms = Date.now() - t0
            if (readBack === token + (n - 1)) pass(i18n.tr("%1 writes + read-back OK in %2 ms").arg(n).arg(ms))
            else fail(i18n.tr("Read-back mismatch"))
        } catch (e) {
            fail(i18n.tr("Storage error: ") + e)
        }
    }
}
