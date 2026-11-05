"""Render the real result delegate with inert Quickshell icon integration."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class LauncherResultRowTests(unittest.TestCase):
    def test_result_kinds_and_live_label_updates(self):
        with tempfile.TemporaryDirectory(prefix="launcher-row-") as directory:
            base = Path(directory)
            source = (ROOT / "launcher/LauncherResultRow.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell"))
            (base / "LauncherResultRow.qml").write_text('import "."\n' + source)
            (base / "Dmenu.js").write_text((ROOT / "launcher/Dmenu.js").read_text())
            (base / "ControlConfig.qml").write_text((ROOT / "tests/components/ControlConfig.qml").read_text())
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function iconPath(name, fallback) { return ""; } }'
            )
            (base / "IconImage.qml").write_text(
                'import QtQuick\nItem { property int implicitSize: 26; property url source: "" }'
            )
            (base / "tst_row.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    ControlConfig { id: fixtureConfig }
    Component {
        id: rowComponent
        LauncherResultRow { config: fixtureConfig; entry: ({type: "application", text: "Test app", icon: ""}); width: 400; height: 46 }
    }
    TestCase {
        name: "LauncherResultRowView"
        function test_result_kinds_data() {
            return ["application", "binary", "emoji", "file", "calculator", "timer-start", "timer-active", "dmenu"].map(type => ({tag: type, type: type}));
        }
        function test_result_kinds(data) {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const row = createTemporaryObject(rowComponent, host);
            row.entry = {type: data.type, text: "Synthetic result", icon: "", emoji: "🙂", subtitle: "Detail"};
            const title = findChild(row, "launcherResultTitle");
            const subtitle = findChild(row, "launcherResultSubtitle");
            verify(title.text.includes("Synthetic result"));
            row.selected = true;
            compare(title.color, fixtureConfig.selectionForeground);
            row.selected = false;
            compare(title.color, fixtureConfig.fg);
            if (data.type === "timer-active") {
                row.remainingText = "1m remaining";
                compare(subtitle.text, "1m remaining");
                row.remainingText = "59s remaining";
                compare(subtitle.text, "59s remaining");
            } else {
                compare(subtitle.text, "Detail");
            }
            compare(title.textFormat, data.type === "dmenu" ? Text.RichText : Text.AutoText);
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
