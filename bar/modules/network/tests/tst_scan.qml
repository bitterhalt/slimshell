import QtQuick
import QtTest
import ".."

Item {
    id: host

    QtObject { id: wifi; property bool scannerEnabled: false }
    QtObject { id: otherWifi; property bool scannerEnabled: false }
    Component { id: scanComponent; ScanState {} }

    TestCase {
        name: "WifiScan"
        property var scan: null

        function init() {
            failOnWarning(/TypeError|Binding loop/);
            wifi.scannerEnabled = false;
            otherWifi.scannerEnabled = false;
            scan = createTemporaryObject(scanComponent, host, {wifiDevice: wifi, allowed: true});
            verify(scan !== null);
        }

        function test_no_scan_on_open() {
            verify(scan.canScan);
            verify(!scan.requested);
            verify(!scan.resultsVisible);
            verify(!wifi.scannerEnabled);
        }

        function test_stop_preserves_results() {
            verify(scan.handleKey(Qt.Key_S, Qt.ControlModifier));
            verify(scan.requested);
            verify(scan.resultsVisible);
            verify(wifi.scannerEnabled);
            verify(scan.handleKey(Qt.Key_S, Qt.ControlModifier));
            verify(!scan.requested);
            verify(scan.resultsVisible);
            verify(!wifi.scannerEnabled);
        }

        function test_ethernet_or_radio_off_stops_scan() {
            scan.toggle();
            scan.allowed = false;
            verify(!scan.requested);
            verify(!scan.resultsVisible);
            verify(!wifi.scannerEnabled);
            verify(!scan.handleKey(Qt.Key_S, Qt.ControlModifier));
            scan.allowed = true;
            verify(scan.canScan);
            verify(!scan.requested);
            verify(!scan.resultsVisible);
        }

        function test_other_shortcuts_are_ignored() {
            verify(!scan.handleKey(Qt.Key_S, Qt.NoModifier));
            verify(!scan.handleKey(Qt.Key_S, Qt.ControlModifier | Qt.AltModifier));
            verify(!scan.handleKey(Qt.Key_Escape, Qt.NoModifier));
            verify(!wifi.scannerEnabled);
        }

        function test_no_device() {
            scan.wifiDevice = null;
            verify(!scan.canScan);
            scan.toggle();
            verify(!scan.requested);
            verify(!scan.resultsVisible);
        }

        function test_device_replacement_releases_previous_scanner() {
            scan.toggle();
            scan.wifiDevice = otherWifi;
            verify(!wifi.scannerEnabled);
            verify(!otherWifi.scannerEnabled);
            verify(!scan.requested);
            verify(!scan.resultsVisible);
            scan.toggle();
            verify(otherWifi.scannerEnabled);
        }

        function test_closing_stops_scan_and_reopening_hides_results() {
            scan.toggle();
            scan.destroy();
            scan = null;
            wait(0);
            verify(!wifi.scannerEnabled);
            scan = createTemporaryObject(scanComponent, host, {wifiDevice: wifi, allowed: true});
            verify(!scan.resultsVisible);
            verify(!scan.requested);
        }
    }
}
