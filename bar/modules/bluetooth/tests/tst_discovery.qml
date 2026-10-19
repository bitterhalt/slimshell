import QtQuick
import QtTest
import ".."

Item {
    id: host

    QtObject {
        id: adapter
        property bool enabled: true
        property bool discovering: false
    }
    QtObject {
        id: service
        property var adapter: null
        property int users: 0
        property int starts: 0
        property int stops: 0
        function beginDiscovery() {
            starts++;
            users++;
            if (adapter)
                adapter.discovering = true;
        }
        function endDiscovery() {
            stops++;
            users = Math.max(0, users - 1);
            if (adapter)
                adapter.discovering = users > 0;
        }
    }
    Component { id: stateComponent; DiscoveryState { bluetoothService: service } }

    TestCase {
        name: "BluetoothDiscovery"
        property var state: null

        function init() {
            failOnWarning(/TypeError|Binding loop/);
            adapter.enabled = true;
            adapter.discovering = false;
            service.adapter = adapter;
            service.users = service.starts = service.stops = 0;
            state = createTemporaryObject(stateComponent, host);
            verify(state !== null);
        }

        function test_no_automatic_scan() {
            verify(!state.requested);
            compare(service.starts, 0);
        }

        function test_start_and_stop() {
            state.toggleDiscovery();
            verify(state.requested);
            verify(adapter.discovering);
            compare(service.users, 1);
            state.toggleDiscovery();
            verify(!state.requested);
            verify(!adapter.discovering);
            compare(service.users, 0);
            state.stop();
            compare(service.stops, 1);
        }

        function test_other_keys_remain_available() {
            verify(!state.handleKey(Qt.Key_O, Qt.NoModifier));
            verify(!state.handleKey(Qt.Key_Menu, Qt.NoModifier));
            verify(!state.handleKey(Qt.Key_F, Qt.NoModifier));
            verify(!state.handleKey(Qt.Key_Return, Qt.NoModifier));
            verify(!state.handleKey(Qt.Key_Escape, Qt.NoModifier));
            verify(!state.handleKey(Qt.Key_O, Qt.ControlModifier));
            verify(!state.requested);
        }

        function test_power_off_stops_owned_scan() {
            state.toggleDiscovery();
            adapter.enabled = false;
            verify(!state.requested);
            compare(service.users, 0);
            adapter.enabled = true;
            verify(!state.requested);
            compare(service.starts, 1);
        }

        function test_ctrl_s_scan_shortcut() {
            verify(state.handleKey(Qt.Key_S, Qt.ControlModifier));
            verify(state.requested);
            verify(adapter.discovering);
            verify(state.handleKey(Qt.Key_S, Qt.ControlModifier));
            verify(!state.requested);
            verify(!adapter.discovering);
            verify(!state.handleKey(Qt.Key_S, Qt.ControlModifier | Qt.AltModifier));
            adapter.enabled = false;
            verify(!state.handleKey(Qt.Key_S, Qt.ControlModifier));
            compare(service.starts, 1);
        }

        function test_no_adapter_or_disabled_adapter() {
            adapter.enabled = false;
            state.toggleDiscovery();
            verify(!state.handleKey(Qt.Key_O, Qt.NoModifier));
            compare(service.starts, 0);
            service.adapter = null;
            state.toggleDiscovery();
            compare(service.starts, 0);
        }

        function test_adapter_removal_stops_request() {
            state.toggleDiscovery();
            service.adapter = null;
            verify(!state.requested);
            compare(service.users, 0);
        }

        function test_close_releases_only_own_request() {
            service.users = 1;
            adapter.discovering = true;
            state.toggleDiscovery();
            compare(service.users, 2);
            state.destroy();
            state = null;
            wait(0);
            compare(service.users, 1);
            verify(adapter.discovering);
        }
    }
}
