"""Service lifecycle tests with inert IPC/process doubles, never live desktop APIs."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]

TEST = r'''
import QtQuick
import QtTest
import "."
Item {
    id: host
    QtObject {
        id: settings
        property int notificationHistoryLimit: 100
        property var notificationHistoryExcludedApps: []
        property int idleLockTimeout: 1200
        property int idleOffTimeout: 1800
        property int idleSuspendTimeout: 7200
    }
    Component { id: notifications; NotificationService { config: settings } }
    Component { id: niri; NiriService {} }
    Component { id: recorder; RecorderService {} }
    Component { id: preferences; SettingsService { config: settings } }
    Component { id: idle; IdleService { lockService: lockStub } }
    Component { id: enabledSpy; SignalSpy { signalName: "automaticEnabledChanged" } }
    QtObject { id: lockStub; function lock() {} }
    TestCase {
        name: "ServiceRegressions"
        function process(service, binary) {
            return Array.from(service.data).find(child => child.command && child.command[0] === binary);
        }
        function file(service) {
            return Array.from(service.data).find(child => child.path !== undefined);
        }
        function test_settings_restore_existing_format_and_legacy_mode() {
            const service = createTemporaryObject(preferences, host);
            const storage = file(service);
            verify(storage.path.endsWith("/quickshell-settings.json"));
            verify(storage.atomicWrites);
            verify(!service.settingsLoaded);
            storage.contents = JSON.stringify({lock: 60, off: 120, suspend: 300,
                hellwalMode: "light-comfort", hellwalDarkOffset: 0.2,
                hellwalBrightOffset: 0.4, workspaceLayout: "minimal"});
            storage.loaded();
            verify(service.settingsLoaded);
            verify(!service.applying);
            compare(service.lockTimeout, 60);
            compare(service.offTimeout, 120);
            compare(service.suspendTimeout, 300);
            compare(service.hellwalMode, "light");
            compare(service.hellwalDarkOffset, 0.2);
            compare(service.hellwalBrightOffset, 0.4);
            compare(service.workspaceLayout, "minimal");
            compare(storage.written, "");
        }
        function test_settings_missing_and_malformed_keep_defaults() {
            for (const malformed of [false, true]) {
                const service = createTemporaryObject(preferences, host);
                const storage = file(service);
                if (malformed) {
                    storage.contents = "invalid JSON";
                    storage.loaded();
                } else {
                    storage.loadFailed();
                }
                verify(service.settingsLoaded);
                verify(!service.applying);
                compare(service.lockTimeout, 1200);
                compare(service.offTimeout, 1800);
                compare(service.suspendTimeout, 7200);
                compare(service.workspaceLayout, "dots");
                compare(storage.written, "");
            }
        }
        function test_settings_saves_preserve_other_domains() {
            const service = createTemporaryObject(preferences, host);
            const storage = file(service);
            verify(service.saveWorkspaceLayout("minimal") !== "");
            compare(storage.written, "");
            storage.loadFailed();
            compare(service.saveWorkspaceLayout("minimal"), "");
            compare(service.saveHellwalSettings("light", 0.2, 0.3), "");
            compare(service.saveTimeouts(60, 120, 300), "");
            const saved = JSON.parse(storage.written);
            compare(saved.lock, 60);
            compare(saved.off, 120);
            compare(saved.suspend, 300);
            compare(saved.hellwalMode, "light");
            compare(saved.hellwalDarkOffset, 0.2);
            compare(saved.hellwalBrightOffset, 0.3);
            compare(saved.workspaceLayout, "minimal");
            const previous = storage.written;
            verify(service.saveTimeouts(-1, 120, 300) !== "");
            verify(service.saveHellwalSettings("invalid", 0, 0) !== "");
            verify(service.saveWorkspaceLayout("invalid") !== "");
            compare(storage.written, previous);
        }
        function test_idle_follows_preferences_without_owning_persistence() {
            const service = createTemporaryObject(preferences, host);
            const runtime = createTemporaryObject(idle, host, {settingsService: service});
            verify(!runtime.automaticEnabled);
            file(service).loadFailed();
            verify(runtime.automaticEnabled);
            const spy = createTemporaryObject(enabledSpy, host, {target: runtime});
            compare(service.saveTimeouts(60, 120, 300), "");
            compare(runtime.lockTimeout, 60);
            compare(runtime.offTimeout, 120);
            compare(runtime.suspendTimeout, 300);
            verify(runtime.automaticEnabled);
            compare(spy.count, 2);
            runtime.toggle(null);
            verify(runtime.disabled);
            verify(!runtime.automaticEnabled);
            verify(runtime.workspaceLayout === undefined);
            verify(runtime.saveTimeouts === undefined);
        }
        function test_suppressed_transient_is_not_retained() {
            const service = createTemporaryObject(notifications, host);
            service.dnd = true;
            const transient = {id: 1, appName: "test", transient: true, tracked: true};
            service.receive(transient);
            verify(!transient.tracked);
            compare(service.toastSerial, 0);
            const normal = {id: 2, appName: "test", transient: false, tracked: false};
            service.receive(normal);
            verify(normal.tracked);
        }
        function test_visible_transient_expires_after_toast() {
            const service = createTemporaryObject(notifications, host);
            let expired = false;
            const notification = {id: 3, appName: "test", transient: true,
                tracked: false, expire: function() { expired = true; }};
            service.receive(notification);
            verify(notification.tracked);
            compare(service.toastSerial, 1);
            service.finishToast(notification);
            verify(expired);
        }
        function test_niri_reconnects_and_valid_events_reset_backoff() {
            const service = createTemporaryObject(niri, host);
            const stream = process(service, "niri");
            verify(stream !== undefined);
            service.reconnectDelay = 1;
            stream.running = false;
            tryCompare(stream, "running", true);
            compare(service.reconnectDelay, 2);
            service.handleNiriEvent('{"WindowFocusChanged":{"id":42}}');
            compare(service.focusedWindowId, 42);
            compare(service.reconnectDelay, 1000);
        }
        function test_fullscreen_uses_selected_output() {
            const service = createTemporaryObject(recorder, host,
                {targetScreen: {name: "DP-2"}});
            service.fullscreen();
            compare(service.pendingTarget, "DP-2");
            process(service, "mkdir").exited(0);
            const capture = process(service, "gpu-screen-recorder");
            verify(capture !== undefined);
            compare(capture.command[1], "-w");
            compare(capture.command[2], "DP-2");
            verify(capture.command.indexOf("-region") === -1);
            verify(capture.command.indexOf("default_output") !== -1);
        }
        function test_region_uses_explicit_geometry_argument() {
            const service = createTemporaryObject(recorder, host);
            service.startRegion("640x480+1920+100");
            process(service, "mkdir").exited(0);
            const capture = process(service, "gpu-screen-recorder");
            compare(capture.command[2], "region");
            const index = capture.command.indexOf("-region");
            verify(index !== -1);
            compare(capture.command[index + 1], "640x480+1920+100");
            verify(capture.command.indexOf("-a") === -1);
            compare(service.pendingRegion, "");
        }
    }
}
'''


class ServiceTests(unittest.TestCase):
    def test_offline_service_lifecycles(self):
        with tempfile.TemporaryDirectory(prefix="shell-services-") as directory:
            base = Path(directory)
            for name in ("NiriService", "RecorderService", "NotificationService",
                         "SettingsService", "IdleService"):
                source = (ROOT / "services" / f"{name}.qml").read_text()
                source = "\n".join(
                    line for line in source.splitlines()
                    if not line.startswith("import Quickshell")
                )
                source = source.replace('"../notifications/', '"')
                (base / f"{name}.qml").write_text('import "."\n' + source)
            for name in ("ToastPolicy.js", "HistoryPolicy.js"):
                (base / name).write_text((ROOT / "notifications" / name).read_text())
            (base / "idle").mkdir()
            (base / "idle" / "Duration.js").write_text(
                (ROOT / "services" / "idle" / "Duration.js").read_text()
            )
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject {\n'
                'function env(name) { return "/synthetic-home"; }\n'
                'function execDetached(command) { throw new Error("Unexpected command"); }\n}\n'
            )
            doubles = {
                "Process": '''QtObject {
                    property bool running: false
                    property var command: []
                    property QtObject stdout
                    signal started()
                    signal exited(int exitCode)
                }''',
                "SplitParser": 'QtObject { signal read(string data) }',
                "IdleMonitor": '''QtObject {
                    property bool enabled: false
                    property bool isIdle: false
                    property int timeout: 0
                    property bool respectInhibitors: false
                }''',
                "FileView": '''QtObject {
                    property string path
                    property bool atomicWrites
                    property bool printErrors
                    property string contents: ""
                    property string written: ""
                    function text() { return contents; }
                    function setText(value) { written = value; }
                    signal loaded()
                    signal loadFailed()
                }''',
                "IpcHandler": 'QtObject { property string target }',
                "NotificationServer": '''QtObject {
                    property var trackedNotifications: ({values: []})
                    property bool bodySupported
                    property bool bodyMarkupSupported
                    property bool imageSupported
                    property bool actionsSupported
                    property bool persistenceSupported
                    property bool keepOnReload
                    signal notification(var notification)
                }''',
            }
            for name, body in doubles.items():
                (base / f"{name}.qml").write_text("import QtQuick\n" + body)
            (base / "tst_services.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
