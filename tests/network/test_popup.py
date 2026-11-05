"""Exercise the actual popup with fake networking; never touch live Wi-Fi."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NetworkPopupTests(unittest.TestCase):
    def test_extracted_pages_and_controller(self):
        with tempfile.TemporaryDirectory(prefix="network-popup-") as directory:
            base = Path(directory)
            for name in ("NetworkPopup.qml", "NetworkActions.qml", "NetworkPasswordForm.qml",
                         "NetworkRow.qml", "ScanState.qml", "Model.js", "ScanOwners.js"):
                source = (ROOT / "bar/modules/network" / name).read_text()
                if name.endswith(".qml"):
                    source = "\n".join(line for line in source.splitlines()
                                       if not line.startswith("import Quickshell")
                                       and line != 'import "../../../components"')
                    source = 'import "."\n' + source
                (base / name).write_text(source)
            for name in ("PopoutPanel.qml", "PanelSurface.qml", "ShellButton.qml", "ShellTextField.qml",
                         "ActionRow.qml", "SelectionIndicator.qml", "ShellIconButton.qml"):
                (base / name).write_text((ROOT / "components" / name).read_text())
            (base / "ControlConfig.qml").write_text((ROOT / "tests/components/ControlConfig.qml").read_text())
            (base / "qmldir").write_text("singleton Networking 1.0 Networking.qml\n")
            (base / "Networking.qml").write_text(
                "pragma Singleton\nimport QtQuick\nQtObject { property bool wifiEnabled: true }"
            )
            (base / "WifiSecurityType.qml").write_text("import QtQuick\nQtObject { enum Security { Open, WpaPsk } }")
            (base / "tst_popup.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    width: 500
    height: 600
    ControlConfig { id: fixtureConfig }
    QtObject {
        id: device
        property bool scannerEnabled: false
    }
    QtObject {
        id: saved
        property bool connected: false
        property bool known: true
        property bool stateChanging: false
        property int connects: 0
        property int forgets: 0
        function connect() { connects++; }
        function disconnect() {}
        function forget() { forgets++; }
    }
    QtObject {
        id: secured
        property bool connected: false
        property bool known: false
        property bool stateChanging: false
        property int security: WifiSecurityType.WpaPsk
        property string receivedPassword: ""
        function connectWithPsk(value) { receivedPassword = value; }
    }
    QtObject {
        id: service
        property var wifiDevice: device
        property bool wifiBrowsingAvailable: true
        property var wiredDevice: null
        property bool wiredConnected: false
        property var connectedWifi: null
        property string connectionKind: "disconnected"
        property var networkRows: [{ssid: "Saved", connected: false, known: true, strength: 0.8}]
        function networkForSsid(ssid) { return ssid === "Saved" ? saved : ssid === "Secured" ? secured : null; }
    }
    QtObject {
        id: manager
        property bool hostFocusable: true
        property int closes: 0
        function closeHost(key) { closes++; }
    }
    Component { id: popupComponent; NetworkPopup { config: fixtureConfig; network: service; popupManager: manager } }
    TestCase {
        name: "NetworkPopupPages"
        when: windowShown
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            saved.connects = saved.forgets = 0;
            secured.receivedPassword = "";
        }
        function test_saved_network_actions_and_keyboard_bubbling() {
            const popup = createTemporaryObject(popupComponent, host);
            popup.openRow({ssid: "Saved"});
            verify(popup.actionMode);
            const connect = findChild(popup, "networkConnectAction");
            tryCompare(connect, "activeFocus", true);
            keyClick(Qt.Key_F);
            compare(saved.forgets, 1);
            verify(!popup.actionMode);
            wait(0);
            popup.openRow({ssid: "Saved"});
            tryCompare(connect, "activeFocus", true);
            waitForPolish(host.Window.window);
            mouseClick(connect, 10, 10);
            compare(saved.connects, 1);
            verify(!popup.actionMode);
        }
        function test_scan_button_toggles_and_respects_availability() {
            const popup = createTemporaryObject(popupComponent, host);
            const button = findChild(popup, "networkScanButton");
            verify(button !== null);
            waitForPolish(host.Window.window);
            mouseClick(button, button.width / 2, button.height / 2);
            verify(device.scannerEnabled);
            compare(button.text, "Stop");
            mouseClick(button, button.width / 2, button.height / 2);
            verify(!device.scannerEnabled);
            service.wifiBrowsingAvailable = false;
            verify(!button.enabled);
            service.wifiBrowsingAvailable = true;
        }
        function test_password_submit_cancel_and_reopen_clear() {
            const popup = createTemporaryObject(popupComponent, host);
            popup.openRow({ssid: "Secured"});
            const input = findChild(popup, "networkPasswordInput");
            tryCompare(input, "activeFocus", true);
            input.text = "synthetic-password";
            keyClick(Qt.Key_Return);
            compare(secured.receivedPassword, "synthetic-password");
            verify(!popup.passwordMode);
            compare(input.text, "");
            popup.openRow({ssid: "Secured"});
            tryCompare(input, "activeFocus", true);
            input.text = "discard-me";
            keyClick(Qt.Key_Escape);
            verify(!popup.passwordMode);
            compare(input.text, "");
            popup.openRow({ssid: "Secured"});
            tryCompare(input, "activeFocus", true);
            compare(input.text, "");
        }
    }
}
''')
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
