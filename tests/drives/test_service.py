"""Drive service with inert udisks/lsblk processes and JSON snapshots."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import run_qml_tests

ROOT = Path(__file__).resolve().parents[2]


TEST = r'''
import QtQuick
import QtTest
import "."

Item {
    id: host

    QtObject {
        id: resume
        signal resumed
    }

    Component {
        id: serviceComponent
        DriveService {
            resumeService: resume
        }
    }

    TestCase {
        name: "DriveService"
        property var service: null

        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            Quickshell.detached = [];
            service = createTemporaryObject(serviceComponent, host);
        }

        function volume(name, options) {
            var node = {
                name: name,
                path: "/dev/" + name,
                size: 32000000000,
                type: "part",
                fstype: "ext4",
                label: name.toUpperCase(),
                mountpoints: [],
                children: []
            };
            var overrides = options || {};
            for (var key in overrides)
                node[key] = overrides[key];
            return node;
        }

        function snapshot(volumes) {
            return JSON.stringify({
                blockdevices: [{
                    name: "sdb",
                    path: "/dev/sdb",
                    size: 32000000000,
                    type: "disk",
                    rm: true,
                    hotplug: true,
                    tran: "usb",
                    model: "USB",
                    children: volumes
                }]
            });
        }

        function manyVolumes(count) {
            var list = [];
            for (var i = 0; i < count; i++)
                list.push(volume("disk" + i + "p1"));
            return list;
        }

        function finishLsblk(payload) {
            const process = findChild(service, "driveLsblkProcess");
            process.stdout.text = payload;
            process.stdout.streamFinished();
            process.exited(0);
            process.running = false;
        }

        function finishLookup(payload) {
            const process = findChild(service, "driveMountLookupProcess");
            verify(process.running);
            process.stdout.text = payload;
            process.stdout.streamFinished();
            process.exited(0);
            process.running = false;
        }

        function applySnapshot(payload) {
            const process = findChild(service, "driveLsblkProcess");
            if (!process.running)
                service.refresh();
            finishLsblk(payload);
        }

        function test_initial_snapshot_and_ipc_status() {
            const process = findChild(service, "driveLsblkProcess");
            verify(process.running);
            compare(process.command[0], "lsblk");
            verify(process.command.includes("-J"));
            finishLsblk(snapshot([
                volume("sdb1", {label: "STICK", mountpoints: ["/run/media/user/STICK"], fsavail: 1000000000}),
                volume("sdc1", {label: "BACKUP"})
            ]));
            compare(service.volumes.length, 2);
            compare(service.volumes[0].path, "/dev/sdb1");
            verify(service.present);
            verify(!service.refreshing);
            const ipc = findChild(service, "driveIpcHandler");
            compare(ipc.target, "drives");
            compare(JSON.parse(ipc.status()).volumes.length, 2);
        }

        function test_invalid_snapshot_keeps_last_inventory() {
            finishLsblk(snapshot([volume("sdb1")]));
            compare(service.volumes.length, 1);
            service.refresh();
            const process = findChild(service, "driveLsblkProcess");
            verify(process.running);
            process.stdout.text = "garbage";
            process.stdout.streamFinished();
            process.exited(0);
            process.running = false;
            compare(service.volumes.length, 1);
            compare(service.inventoryError, "Could not read the drive list");
        }

        function test_monitor_events_debounce_a_snapshot() {
            finishLsblk(snapshot([]));
            const monitor = findChild(service, "driveMonitorProcess");
            const timer = findChild(service, "driveDebounceTimer");
            verify(monitor.running);
            compare(monitor.command[0], "udisksctl");
            verify(!timer.running);
            monitor.stdout.read("Monitoring the udisks daemon. Press Ctrl+C to exit.");
            verify(!timer.running);
            monitor.stdout.read("20:14:03.031: Device /dev/sdb1 mounted at /run/media/user/STICK");
            verify(timer.running);
            timer.triggered();
            verify(findChild(service, "driveLsblkProcess").running);
        }

        function test_actions_report_failure_and_refresh() {
            finishLsblk(snapshot([volume("sdb1", {label: "STICK"})]));
            const action = findChild(service, "driveActionProcess");
            verify(service.mount("/dev/sdb1"));
            compare(action.command, ["udisksctl", "mount", "-b", "/dev/sdb1", "--no-user-interaction"]);
            verify(action.running);
            compare(service.busyPath, "/dev/sdb1");
            action.stderr.text = "Error: not authorized\nsecond line";
            action.stderr.streamFinished();
            action.exited(1);
            action.running = false;
            compare(service.errorText, "Error: not authorized");
            compare(service.busyPath, "");
            verify(findChild(service, "driveLsblkProcess").running);
            finishLsblk(snapshot([volume("sdb1")]));
            // A successful snapshot must not hide a failed action too quickly.
            compare(service.errorText, "Error: not authorized");
            compare(service.inventoryError, "");
            verify(service.mount("/dev/sdb1"));
            compare(service.errorText, "");
            verify(!service.mount("relative"));
            compare(service.errorText, "Invalid device path");
        }

        function test_open_and_activate_follow_mount_state() {
            finishLsblk(snapshot([
                volume("sdb1", {mountpoints: ["/run/media/user/STICK"]}),
                volume("sdc1"),
                {name: "sdd1", path: "/dev/sdd1", type: "part", fstype: "crypto_LUKS", label: "LOCKED", mountpoints: [], children: []}
            ]));
            verify(service.open("/dev/sdb1"));
            compare(Quickshell.detached.length, 1);
            compare(Quickshell.detached[0], ["xdg-open", "/run/media/user/STICK"]);
            verify(!service.open("/dev/sdc1"));
            compare(Quickshell.detached.length, 1);
            compare(service.errorText, "Drive is not mounted");
            verify(service.activate(service.volumes[0]));
            compare(Quickshell.detached.length, 2);
            verify(service.activate(service.volumes[1]));
            const action = findChild(service, "driveActionProcess");
            verify(action.running);
            compare(action.command[1], "mount");
            compare(service.busyPath, "/dev/sdc1");
            verify(!service.activate(service.volumes[2]));
            compare(service.busyPath, "/dev/sdc1");
        }

        function test_bar_mount_opens_mountpoint_after_success() {
            applySnapshot(snapshot([volume("sdb1")]));
            const action = findChild(service, "driveActionProcess");
            const lookup = findChild(service, "driveMountLookupProcess");
            verify(service.activate(service.volumes[0]));
            verify(action.running);
            compare(action.command[1], "mount");
            compare(service.pendingOpenPath, "/dev/sdb1");
            verify(!lookup.running);
            action.exited(0);
            action.running = false;
            compare(service.pendingOpenPath, "");
            verify(lookup.running);
            compare(lookup.command, ["lsblk", "-n", "-o", "MOUNTPOINTS", "/dev/sdb1"]);
            finishLookup("\n/run/media/user/STICK\n");
            compare(Quickshell.detached.length, 1);
            compare(Quickshell.detached[0], ["xdg-open", "/run/media/user/STICK"]);
        }

        function test_failed_bar_mount_does_not_open() {
            applySnapshot(snapshot([volume("sdb1")]));
            const action = findChild(service, "driveActionProcess");
            const lookup = findChild(service, "driveMountLookupProcess");
            verify(service.activate(service.volumes[0]));
            action.stderr.text = "Error: not authorized";
            action.stderr.streamFinished();
            action.exited(1);
            action.running = false;
            compare(service.pendingOpenPath, "");
            verify(!lookup.running);
            compare(Quickshell.detached.length, 0);
            compare(service.errorText, "Error: not authorized");
        }

        function test_ipc_mount_does_not_open() {
            applySnapshot(snapshot([volume("sdb1")]));
            const ipc = findChild(service, "driveIpcHandler");
            const action = findChild(service, "driveActionProcess");
            const lookup = findChild(service, "driveMountLookupProcess");
            compare(ipc.mount("/dev/sdb1"), "ok");
            compare(service.pendingOpenPath, "");
            action.exited(0);
            action.running = false;
            verify(!lookup.running);
            compare(Quickshell.detached.length, 0);
        }

        function test_compact_staging_uses_hysteresis() {
            applySnapshot(snapshot(manyVolumes(4)));
            verify(!service.compact);
            applySnapshot(snapshot(manyVolumes(5)));
            verify(service.compact);
            applySnapshot(snapshot(manyVolumes(4)));
            verify(service.compact);
            applySnapshot(snapshot(manyVolumes(3)));
            verify(!service.compact);
        }

        function test_resume_refreshes_inventory() {
            finishLsblk(snapshot([]));
            resume.resumed();
            verify(findChild(service, "driveLsblkProcess").running);
        }

        function test_monitor_reconnects_after_exit() {
            finishLsblk(snapshot([]));
            const monitor = findChild(service, "driveMonitorProcess");
            const timer = findChild(service, "driveReconnectTimer");
            monitor.exited(1);
            monitor.running = false;
            verify(timer.running);
            compare(timer.interval, 5000);
            timer.triggered();
            verify(monitor.running);
            verify(findChild(service, "driveLsblkProcess").running);
        }

        function test_ipc_rejects_invalid_devices() {
            const ipc = findChild(service, "driveIpcHandler");
            compare(ipc.mount("/etc/passwd"), "error");
            compare(ipc.unmount("/etc/passwd"), "error");
            compare(ipc.poweroff("/etc/passwd"), "error");
            compare(ipc.open("/dev/sdb1"), "error");
            const status = JSON.parse(ipc.status());
            compare(status.error, "Drive is not mounted");
            compare(status.volumes, []);
        }
    }
}
'''


DOUBLES = {
    "Process": '''import QtQuick
QtObject {
    property bool running: false
    property var command: []
    property bool exitSeen: false
    property QtObject stdout: null
    property QtObject stderr: null
    signal exited(int exitCode)
}''',
    "SplitParser": 'import QtQuick\nQtObject { signal read(string data) }',
    "StdioCollector": '''import QtQuick
QtObject {
    property string text: ""
    signal streamFinished()
}''',
    "IpcHandler": 'import QtQuick\nQtObject { property string target: "" }',
    "Quickshell": '''pragma Singleton
import QtQuick
QtObject {
    property var detached: []
    function execDetached(command) {
        detached = detached.concat([command]);
    }
}''',
}


class DriveServiceTests(unittest.TestCase):
    def test_offline_service(self):
        with tempfile.TemporaryDirectory(prefix="drives-service-") as directory:
            base = Path(directory)
            source = (ROOT / "services/DriveService.qml").read_text()
            source = source.replace('import "drives/DriveModel.js"', 'import "DriveModel.js"')
            source = source.replace("import Quickshell.Io\n", "").replace("import Quickshell\n", "")
            (base / "DriveService.qml").write_text('import "."\n' + source)
            (base / "DriveModel.js").write_text(
                (ROOT / "services/drives/DriveModel.js").read_text()
            )
            for name, body in DOUBLES.items():
                (base / f"{name}.qml").write_text(body)
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "tst_service.qml").write_text(TEST)
            run_qml_tests(directory)
