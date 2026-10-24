import QtQuick 2.12
import Lomiri.Components 1.3
import QtBluetooth 5.12
import ".."

// Starts a discovery: passes as soon as a nearby device is seen.
TestBase {
    id: root
    timeoutMs: 40000

    BluetoothDiscoveryModel {
        id: disc
        running: false
        discoveryMode: BluetoothDiscoveryModel.DeviceDiscovery
        onDeviceDiscovered: root.pass(i18n.tr("Device found: ") + device)
        onErrorChanged: {
            if (error === BluetoothDiscoveryModel.PoweredOffError) root.fail(i18n.tr("Bluetooth is off"))
            else if (error === BluetoothDiscoveryModel.InvalidBluetoothAdapterError) root.fail(i18n.tr("No Bluetooth adapter"))
            else if (error !== BluetoothDiscoveryModel.NoError) root.fail(i18n.tr("Bluetooth error ") + error)
        }
    }

    function run() {
        note(i18n.tr("Scanning Bluetooth… (turn it on and put a discoverable device nearby)"))
        disc.running = true
    }
    function cleanup() { disc.running = false }
}
