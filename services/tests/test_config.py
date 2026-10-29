"""JSON config/adapter tests with in-memory files, never the live settings file."""

import json
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
import "config/Schema.js" as Schema
Item {
    id: host
    QtObject {
        id: fixtureTheme
        property color bg: "#101010"
        property color fg: "#eeeeee"
        property color muted: "#888888"
        property color urgent: "#ff5555"
        property color selectionBackground: "#6699cc"
        readonly property color border: Qt.alpha(selectionBackground, 0.45)
        property color selectionForeground: "#ffffff"
    }
    Component { id: configComponent; Config { theme: fixtureTheme } }
    Component { id: settingsComponent; SettingsService {} }
    TestCase {
        name: "JsonConfiguration"
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            TestFiles.configuration = "{}";
        }
        function storage(service) {
            return Array.from(service.data).find(child => child.path !== undefined);
        }
        function test_shipped_json_is_valid() {
            const parsed = Schema.parse(TestFiles.shipped);
            compare(parsed.warnings.length, 0);
        }
        function test_missing_keys_and_empty_array() {
            const parsed = Schema.parse('{"notifications":{"historyExcludedApps":[]}}');
            compare(parsed.values.popupOpenDuration, 100);
            compare(parsed.values.fontScale, 1);
            compare(parsed.values.notificationHistoryExcludedApps.length, 0);
            compare(parsed.warnings.length, 0);
        }
        function test_invalid_values_use_defaults() {
            const parsed = Schema.parse(JSON.stringify({
                appearance: {fontScale: "large"}, bar: {height: 32.5},
                audio: {maxVolume: -1}, animations: {style: "spin", openDuration: -10},
                notifications: {historyExcludedApps: [null]}, clock: []
            }));
            compare(parsed.values.fontScale, 1);
            compare(parsed.values.barHeight, 32);
            compare(parsed.values.maxVolume, 1.1);
            compare(parsed.values.popupAnimationStyle, "fade");
            compare(parsed.values.popupOpenDuration, 100);
            verify(parsed.warnings.length >= 6);
        }
        function test_cross_field_validation() {
            const parsed = Schema.parse('{"bluetooth":{"batteryWarningPercent":5,"batteryCriticalPercent":90}}');
            compare(parsed.values.bluetoothBatteryCriticalPercent, 5);
            const disabledLow = Schema.parse('{"bluetooth":{"batteryWarningPercent":0}}');
            compare(disabledLow.values.bluetoothBatteryCriticalPercent, 10);
        }
        function test_unknown_keys_warn_instead_of_silently_ignoring_typos() {
            const parsed = Schema.parse('{"appearance":{"fontScael":2},"typo":{}}');
            compare(parsed.values.fontScale, 1);
            compare(parsed.warnings.length, 2);
        }
        function test_adapter_initial_load_and_reload() {
            TestFiles.configuration = '{"appearance":{"fontScale":1.25},"animations":{"openDuration":210}}';
            const config = createTemporaryObject(configComponent, host);
            verify(config.ready);
            compare(config.fontScale, 1.25);
            compare(config.popupOpenDuration, 210);
            const file = storage(config);
            verify(file.path.endsWith("/settings.json"));
            verify(file.watchChanges);
            verify(file.blockLoading);
            file.contents = '{"animations":{"enabled":false,"openDuration":80}}';
            file.loaded();
            verify(!config.popupAnimations);
            compare(config.popupOpenDuration, 80);
            file.contents = "malformed JSON";
            file.loaded();
            compare(config.popupOpenDuration, 80);
            verify(!config.applying);
            file.loadFailed();
            compare(config.popupOpenDuration, 80);
        }
        function test_audio_and_animation_values_update_through_file_reload() {
            const config = createTemporaryObject(configComponent, host);
            const file = storage(config);
            file.contents = JSON.stringify({audio: {style: "circle"}, animations: {
                enabled: false, style: "slide", notificationStyle: "fade",
                openDuration: 250, closeDuration: 200,
                hostStyles: {network: "fade"}
            }});
            file.loaded();
            compare(config.audioStyle, "circle");
            verify(!config.popupAnimations);
            compare(config.popupAnimationStyle, "slide");
            compare(config.notificationAnimationStyle, "fade");
            compare(config.popupOpenDuration, 250);
            compare(config.popupCloseDuration, 200);
            compare(config.popupAnimationTypes.network, "fade");
            file.contents = '{"audio":{"style":"classic"},"animations":{"enabled":true}}';
            file.loaded();
            compare(config.audioStyle, "classic");
            verify(config.popupAnimations);
            compare(Object.keys(config.popupAnimationTypes).length, 0);
        }
        function test_json_reload_does_not_change_saved_idle_preferences() {
            const config = createTemporaryObject(configComponent, host);
            const service = createTemporaryObject(settingsComponent, host);
            storage(service).contents = '{"lock":60,"off":120,"suspend":300}';
            storage(service).loaded();
            config.applySettings('{"animations":{"openDuration":250}}');
            compare(service.lockTimeout, 60);
            compare(service.offTimeout, 120);
            verify(!service.applying);
        }
        function test_idle_defaults_are_owned_only_by_settings_service() {
            const config = createTemporaryObject(configComponent, host);
            const service = createTemporaryObject(settingsComponent, host);
            storage(service).loadFailed();
            compare(service.lockTimeout, 1200);
            compare(service.offTimeout, 1800);
            compare(service.suspendTimeout, 7200);
            verify(config.idleLockTimeout === undefined);
            compare(service.saveTimeouts(60, 120, 300), "");
            compare(service.lockTimeout, 60);
            compare(service.offTimeout, 120);
        }
    }
}
'''


class ConfigTests(unittest.TestCase):
    def test_json_adapter(self):
        with tempfile.TemporaryDirectory(prefix="shell-config-") as directory:
            base = Path(directory)
            for name in ("Config.qml", "SettingsService.qml"):
                source = (ROOT / "services" / name).read_text()
                source = "\n".join(line for line in source.splitlines()
                                   if not line.startswith("import Quickshell"))
                (base / name).write_text('import "."\n' + source)
            for folder, name in (("config", "Schema.js"), ("idle", "Duration.js")):
                (base / folder).mkdir()
                (base / folder / name).write_text((ROOT / "services" / folder / name).read_text())
            (base / "qmldir").write_text(
                "singleton Quickshell 1.0 Quickshell.qml\n"
                "singleton TestFiles 1.0 TestFiles.qml\n"
            )
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function env(name) { return "/synthetic-home"; } }\n'
            )
            shipped = json.dumps((ROOT / "settings.json").read_text())
            (base / "TestFiles.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject {\n'
                'property string configuration: "{}"\n'
                f'property string shipped: {shipped}\n}}\n'
            )
            (base / "FileView.qml").write_text('''import QtQuick
import "."
QtObject {
    property string path
    property bool watchChanges: false
    property bool blockLoading: false
    property bool printErrors: false
    property bool atomicWrites: false
    property string contents: path.endsWith("/settings.json") ? TestFiles.configuration : ""
    function text() { return contents; }
    function setText(value) { contents = value; }
    function reload() { loaded(); }
    signal loaded()
    signal fileChanged()
    signal loadFailed()
}
''')
            (base / "tst_config.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
