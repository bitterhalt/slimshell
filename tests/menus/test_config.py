"""Offline validation of shipped menus and live reload with inert file access."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MenuConfigTests(unittest.TestCase):
    def test_load_reload_and_keep_last_valid_menus(self):
        with tempfile.TemporaryDirectory(prefix="menu-config-") as directory:
            base = Path(directory)
            source = (ROOT / "menus/MenuConfig.qml").read_text().replace("import Quickshell.Io", 'import "."')
            (base / "MenuConfig.qml").write_text(source)
            (base / "MenuSchema.js").write_text((ROOT / "menus/MenuSchema.js").read_text())
            shipped = (ROOT / "menus.json").read_text()
            (base / "TestData.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { readonly property string shipped: '
                + json.dumps(shipped) + ' }'
            )
            (base / "qmldir").write_text("singleton TestData 1.0 TestData.qml\n")
            (base / "FileView.qml").write_text('''import QtQuick
QtObject {
    property string path: ""
    property bool blockLoading: false
    property bool watchChanges: false
    property bool printErrors: true
    property string contents: TestData.shipped
    signal loaded()
    signal loadFailed()
    signal fileChanged()
    function text() { return contents; }
    function reload() { loaded(); }
}
''')
            (base / "tst_config.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    Component { id: configComponent; MenuConfig {} }
    TestCase {
        name: "MenuConfiguration"
        function test_initial_load_and_live_reload() {
            const config = createTemporaryObject(configComponent, host);
            verify(config.ready);
            compare(config.errorText, "");
            verify(config.menus["user-menu1"].length > 0);
            verify(config.menus["user-menu3"].some(entry => entry.action === "idleSettings"));
            compare(config.menus["user-menu4"].length, 0);
            const file = findChild(config, "menuConfigurationFile");
            verify(file.watchChanges);
            file.contents = JSON.stringify({"user-menu3": [{label: "Custom", command: "foot"}]});
            file.fileChanged();
            compare(config.menus["user-menu3"][0].label, "Custom");
            compare(config.menus["user-menu1"].length, 0);
            file.contents = "{";
            file.loaded();
            verify(config.errorText !== "");
            compare(config.menus["user-menu3"][0].label, "Custom");
            file.loadFailed();
            compare(config.menus["user-menu3"][0].label, "Custom");
            file.contents = "{}";
            file.loaded();
            compare(config.errorText, "");
            compare(config.menus["user-menu3"].length, 0);
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
