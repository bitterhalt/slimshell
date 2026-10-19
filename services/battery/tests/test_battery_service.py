"""Test battery bindings with UPower doubles; no live shell or laptop needed."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SERVICE = Path(__file__).resolve().parents[2] / "BatteryService.qml"
TEST = '''import QtQuick
import QtTest
import "."

Item {
    id: host
    QtObject {
        id: battery
        property bool ready: true
        property bool isLaptopBattery: true
        property bool isPresent: true
        property real percentage: 57.6
        property int state: UPowerDeviceState.Discharging
    }
    Component { id: serviceComponent; BatteryService {} }
    TestCase {
        name: "BatteryService"
        property var service: null
        function init() {
            failOnWarning(/TypeError|Binding loop/);
            battery.ready = true;
            battery.isLaptopBattery = true;
            battery.isPresent = true;
            battery.percentage = 57.6;
            battery.state = UPowerDeviceState.Discharging;
            UPower.displayDevice = battery;
            service = createTemporaryObject(serviceComponent, host);
            verify(service !== null);
        }
        function test_desktop_without_battery() {
            UPower.displayDevice = null;
            verify(!service.present);
            compare(service.capacity, 0);
            compare(service.status, "");
        }
        function test_waits_for_ready_device() {
            battery.ready = false;
            verify(!service.present);
            battery.ready = true;
            verify(service.present);
        }
        function test_peripherals_are_not_system_batteries() {
            battery.isLaptopBattery = false;
            verify(!service.present);
        }
        function test_removable_battery() {
            battery.isPresent = false;
            verify(!service.present);
            battery.isPresent = true;
            verify(service.present);
        }
        function test_percentage_updates_without_polling() {
            compare(service.capacity, 58);
            battery.percentage = 12.2;
            compare(service.capacity, 12);
            battery.percentage = 150;
            compare(service.capacity, 100);
            battery.percentage = -5;
            compare(service.capacity, 0);
            battery.percentage = NaN;
            compare(service.capacity, 0);
        }
        function test_charging_and_discharging_icons() {
            compare(service.status, "Discharging");
            const dischargingIcon = service.icon;
            battery.state = UPowerDeviceState.Charging;
            compare(service.status, "Charging");
            const chargingIcon = service.icon;
            verify(chargingIcon !== dischargingIcon);
            battery.state = UPowerDeviceState.Discharging;
            compare(service.icon, dischargingIcon);
            battery.state = UPowerDeviceState.PendingCharge;
            compare(service.status, "Not charging");
            verify(service.icon !== chargingIcon);
        }
        function test_full_empty_unknown_states() {
            battery.state = UPowerDeviceState.FullyCharged;
            battery.percentage = 100;
            compare(service.status, "Full");
            verify(service.icon.length > 0);
            battery.state = UPowerDeviceState.Empty;
            battery.percentage = 0;
            compare(service.status, "Empty");
            verify(service.icon.length > 0);
            battery.state = UPowerDeviceState.Unknown;
            compare(service.status, "Unknown");
        }
        function test_display_device_replacement() {
            UPower.displayDevice = null;
            verify(!service.present);
            battery.percentage = 33;
            UPower.displayDevice = battery;
            verify(service.present);
            compare(service.capacity, 33);
        }
    }
}
'''


class BatteryServiceTests(unittest.TestCase):
    def test_upower_bindings(self):
        source = SERVICE.read_text().replace('import Quickshell.Services.UPower', 'import "."')
        with tempfile.TemporaryDirectory(prefix="battery-service-") as folder:
            base = Path(folder)
            (base / "BatteryService.qml").write_text(source)
            (base / "qmldir").write_text(
                "singleton UPower 1.0 UPower.qml\n"
                "UPowerDeviceState 1.0 UPowerDeviceState.qml\n"
            )
            (base / "UPower.qml").write_text(
                "pragma Singleton\nimport QtQuick\n"
                "QtObject { property var displayDevice: null }\n"
            )
            (base / "UPowerDeviceState.qml").write_text(
                "import QtQuick\nQtObject { enum State { Unknown, Charging, "
                "Discharging, Empty, FullyCharged, PendingCharge, PendingDischarge } }\n"
            )
            (base / "tst_battery.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", folder, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
