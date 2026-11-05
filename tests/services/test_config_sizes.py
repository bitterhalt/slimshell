"""Numeric size bindings from the real Config, with an inert settings reader."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ConfigSizeTests(unittest.TestCase):
    def test_numeric_sizes_react_to_independent_scales(self):
        with tempfile.TemporaryDirectory(prefix="config-sizes-") as directory:
            base = Path(directory)
            source = (ROOT / "services/Config.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell"))
            source = source.replace('"config/Schema.js"', '"Schema.js"')
            (base / "Config.qml").write_text('import "."\n' + source)
            (base / "Schema.js").write_text((ROOT / "services/config/Schema.js").read_text())
            (base / "ControlConfig.qml").write_text((ROOT / "tests/components/ControlConfig.qml").read_text())
            (base / "FileView.qml").write_text('''import QtQuick
Item {
    property string path: ""
    property bool blockLoading: false
    property bool watchChanges: false
    property bool printErrors: false
    signal fileChanged
    signal loaded
    signal loadFailed
    function text() { return "{}"; }
    function reload() {}
}
''')
            (base / "tst_sizes.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    ControlConfig { id: fixtureTheme }
    Component { id: configComponent; Config { theme: fixtureTheme } }
    TestCase {
        name: "NumericConfigSizes"
        function test_scales_remain_live_and_independent() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const config = createTemporaryObject(configComponent, host);
            compare(typeof config.fontSize, "number");
            compare(typeof config.iconSize, "number");
            const base = config.systemFontPointSize;
            compare(config.spacingTight, 4);
            compare(config.spacingControl, 8);
            compare(config.panelPadding, 12);
            compare(config.previewPadding, 16);
            compare(config.fontSize, base);
            compare(config.textSizeNormal, base);
            fuzzyCompare(config.textSizeMedium, base * 0.88, 0.001);
            fuzzyCompare(config.textSizeSmall, base * 0.76, 0.001);
            compare(config.iconSize, base);
            config.applySettings('{"appearance":{"fontScale":1.5,"iconScale":1.2}}');
            fuzzyCompare(config.fontSize, base * 1.5, 0.001);
            fuzzyCompare(config.textSizeNormal, base * 1.5, 0.001);
            fuzzyCompare(config.textSizeMedium, base * 1.5 * 0.88, 0.001);
            fuzzyCompare(config.textSizeSmall, base * 1.5 * 0.76, 0.001);
            fuzzyCompare(config.iconSize, base * 1.5 * 1.2, 0.001);
            fuzzyCompare(config.fontSize * 0.88, base * 1.5 * 0.88, 0.001);
            config.applySettings('{"appearance":{"fontScale":1.5,"iconScale":0.8}}');
            fuzzyCompare(config.textSizeMedium, base * 1.5 * 0.88, 0.001);
            fuzzyCompare(config.textSizeSmall, base * 1.5 * 0.76, 0.001);
            fuzzyCompare(config.fontSize, base * 1.5, 0.001);
            fuzzyCompare(config.iconSize, base * 1.5 * 0.8, 0.001);
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
