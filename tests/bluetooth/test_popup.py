"""Exercise the real Bluetooth bar/popup offscreen with inert icon integration."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import copy_control_config, run_qml_tests

ROOT = Path(__file__).resolve().parents[2] / "bar/modules/bluetooth"

TEST = '''import QtQuick
import QtTest
import "."
Item {
    id: host
    width: 500
    height: 600
    ControlConfig {
        id: fixtureConfig
        bg: "#111111"
        fg: "white"
        muted: "gray"
        urgent: "red"
        selectionBackground: "orange"
        selectionForeground: "black"
        iconSize: 12
    }
    QtObject {
        id: fixtureAdapter
        property bool enabled: true
        property bool discovering: false
    }
    QtObject {
        id: service
        property var adapter: fixtureAdapter
        property var devices: [
            {address: "a", name: "Alpha", paired: true, connected: true},
            {address: "b", name: "Beta", paired: true, connected: false}
        ]
        property int toggles: 0
        property int trusts: 0
        property int forgets: 0
        property int scans: 0
        function toggleDevice(row) { toggles++; }
        function toggleTrust(row) { trusts++; }
        function forgetDevice(row) { forgets++; }
        function beginDiscovery() { scans++; }
        function endDiscovery() { scans--; }
    }
    QtObject {
        id: ui
        property var targetScreen: null
        signal bluetoothActionRequested(string action)
    }
    QtObject {
        id: fixtureBarWindow
        property int height: 30
        property var screen: null
    }
    QtObject {
        id: manager
        property var popup: null
        function openHost(key, component, anchor, focusable) {
            if (!popup)
                popup = component.createObject(host);
        }
        function toggleHost(key, component, anchor, focusable) {
            if (popup) closeHost(key);
            else openHost(key, component, anchor, focusable);
        }
        function closeHost(key) {
            if (popup) popup.destroy();
            popup = null;
        }
    }
    Component {
        id: barComponent
        Bluetooth {
            config: fixtureConfig
            barWindow: fixtureBarWindow
            popupManager: manager
            bluetoothService: service
            uiService: ui
        }
    }
    TestCase {
        name: "BluetoothPopupExtraction"
        when: windowShown
        property var bar: null
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            service.toggles = service.trusts = service.forgets = service.scans = 0;
            bar = createTemporaryObject(barComponent, host);
            ui.bluetoothActionRequested("open");
            verify(manager.popup !== null);
            tryVerify(() => manager.popup.activeFocus);
        }
        function cleanup() {
            manager.closeHost("bluetooth");
            wait(0);
        }
        function test_keyboard_actions_and_confirmation() {
            keyClick(Qt.Key_J);
            compare(manager.popup.selectedAddress, "b");
            keyClick(Qt.Key_Return);
            compare(service.toggles, 1);
            keyClick(Qt.Key_T);
            compare(service.trusts, 1);
            keyClick(Qt.Key_F);
            verify(manager.popup.confirmForget);
            keyClick(Qt.Key_Escape);
            verify(!manager.popup.confirmForget);
            compare(service.forgets, 0);
            keyClick(Qt.Key_F);
            keyClick(Qt.Key_Return);
            compare(service.forgets, 1);
        }
        function test_scan_button_starts_and_stops_discovery() {
            const button = findChild(manager.popup, "bluetoothScanButton");
            verify(button !== null);
            waitForPolish(host.Window.window);
            mouseClick(button, button.width / 2, button.height / 2);
            compare(service.scans, 1);
            compare(button.text, "Stop");
            mouseClick(button, button.width / 2, button.height / 2);
            compare(service.scans, 0);
            compare(button.text, "Scan");
        }
        function test_reopen_preserves_selection_but_resets_popup_state() {
            manager.popup.selectDevice(1);
            manager.popup.helpOpen = true;
            keyClick(Qt.Key_S, Qt.ControlModifier);
            compare(service.scans, 1);
            ui.bluetoothActionRequested("close");
            wait(0);
            compare(service.scans, 0);
            compare(bar.selectedAddress, "b");
            ui.bluetoothActionRequested("open");
            compare(manager.popup.selectedAddress, "b");
            verify(!manager.popup.helpOpen);
            verify(!manager.popup.confirmForget);
        }
    }
}
'''


class BluetoothPopupTests(unittest.TestCase):
    def test_popup_and_bar(self):
        with tempfile.TemporaryDirectory(prefix="bluetooth-popup-") as directory:
            base = Path(directory)
            for name in ("Bluetooth.qml", "BluetoothPopup.qml", "BluetoothDeviceRow.qml", "DiscoveryState.qml", "Model.js"):
                source = (ROOT / name).read_text()
                if name.endswith(".qml"):
                    source = "\n".join(line for line in source.splitlines()
                                       if not line.startswith("import Quickshell")
                                       and line != 'import "../../../components"')
                    source = 'import "."\n' + source
                (base / name).write_text(source)
            for name in ("PopoutPanel.qml", "PanelSurface.qml", "PanelSeparator.qml", "SelectionIndicator.qml", "ShellButton.qml", "ShellIconButton.qml"):
                (base / name).write_text((ROOT.parents[2] / "components" / name).read_text())
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function iconPath(name) { return ""; } }'
            )
            (base / "IconImage.qml").write_text(
                'import QtQuick\nItem { property int implicitSize: 18; property url source: "" }'
            )
            copy_control_config(base)
            (base / "tst_popup.qml").write_text(TEST)
            run_qml_tests(directory)
