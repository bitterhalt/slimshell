import QtQuick
import QtTest
import ".."

Item {
    id: host

    QtObject {
        id: device
        property bool connected: false
        property bool paired: false
        property bool pairing: false
    }
    Component { id: watcherComponent; ConnectionWatcher {} }

    TestCase {
        name: "BluetoothConnectionNotification"
        property var watcher: null
        property int notifications: 0

        function createWatcher() {
            watcher = createTemporaryObject(watcherComponent, host, {device: device});
            verify(watcher !== null);
            watcher.connectionReady.connect(item => {
                compare(item, device);
                notifications++;
            });
        }
        function init() {
            device.connected = false;
            device.paired = false;
            device.pairing = false;
            notifications = 0;
        }

        function test_connected_before_paired_waits() {
            createWatcher();
            device.connected = true;
            compare(notifications, 0);
            device.paired = true;
            compare(notifications, 1);
        }

        function test_pairing_must_finish() {
            createWatcher();
            device.pairing = true;
            device.connected = true;
            device.paired = true;
            compare(notifications, 0);
            device.pairing = false;
            compare(notifications, 1);
        }

        function test_paired_device_reconnects() {
            device.paired = true;
            createWatcher();
            device.connected = true;
            compare(notifications, 1);
            device.connected = false;
            device.connected = true;
            compare(notifications, 2);
        }

        function test_failed_pairing_never_notifies() {
            createWatcher();
            device.pairing = true;
            device.connected = true;
            device.connected = false;
            device.pairing = false;
            compare(notifications, 0);
        }

        function test_existing_connection_is_quiet_on_startup() {
            device.connected = true;
            device.paired = true;
            createWatcher();
            compare(notifications, 0);
            device.pairing = true;
            device.pairing = false;
            compare(notifications, 0);
        }

        function test_no_duplicate_within_connection() {
            createWatcher();
            device.connected = true;
            device.paired = true;
            compare(notifications, 1);
            device.pairing = true;
            device.pairing = false;
            device.paired = false;
            device.paired = true;
            compare(notifications, 1);
        }

        function test_no_device() {
            watcher = createTemporaryObject(watcherComponent, host, {device: null});
            verify(watcher !== null);
            verify(!watcher.ready);
        }
    }
}
