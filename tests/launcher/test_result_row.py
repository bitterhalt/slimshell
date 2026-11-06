"""Render the real result delegate with inert Quickshell icon integration."""
from pathlib import Path
import re
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import copy_control_config, run_qml_tests

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
            copy_control_config(base)
            launcher = (ROOT / "launcher/Launcher.qml").read_text()
            metrics = []
            for name in ("panelInset", "inputHeight", "contentSpacing", "rowHeight", "availableDmenuRows", "cardHeight"):
                match = re.search(r"^    readonly property int " + name + r":[^\n]+", launcher, re.M)
                self.assertIsNotNone(match, name)
                metrics.append(match.group())
            (base / "LayoutMetrics.qml").write_text('''import QtQuick
QtObject {
    required property var config
    property var targetScreen: null
    property int maxVisibleRows: 7
    property int visibleRows: 7
''' + "\n".join(metrics) + "\n}\n")
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
        LauncherResultRow { config: fixtureConfig; entry: ({type: "application", text: "Test app", icon: ""}); width: 400; height: 36 }
    }
    Component { id: metricsComponent; LayoutMetrics { config: fixtureConfig } }
    TestCase {
        name: "LauncherResultRowView"
        function test_card_spacing_and_dmenu_screen_fit() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const metrics = createTemporaryObject(metricsComponent, host);
            compare(metrics.panelInset, fixtureConfig.panelPadding);
            compare(metrics.rowHeight, 36);
            compare(metrics.inputHeight - metrics.panelInset, metrics.rowHeight);
            compare(metrics.contentSpacing, fixtureConfig.panelPadding);
            compare(metrics.cardHeight, metrics.inputHeight + metrics.rowHeight * 7 + metrics.contentSpacing + metrics.panelInset);
            metrics.targetScreen = {height: 400};
            metrics.visibleRows = metrics.availableDmenuRows;
            verify(metrics.cardHeight <= 400 - fixtureConfig.popupGap * 2);
            verify(metrics.cardHeight + metrics.rowHeight > 400 - fixtureConfig.popupGap * 2);
            metrics.targetScreen = {height: 40};
            compare(metrics.availableDmenuRows, 0);
        }
        function test_result_kinds_data() {
            return ["application", "binary", "emoji", "file", "calculator", "timer-start", "timer-active", "dmenu"].map(type => ({tag: type, type: type}));
        }
        function test_result_kinds(data) {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const row = createTemporaryObject(rowComponent, host);
            row.entry = {type: data.type, text: "Synthetic result", icon: "", emoji: "🙂", subtitle: "Detail"};
            const title = findChild(row, "launcherResultTitle");
            const subtitle = findChild(row, "launcherResultSubtitle");
            compare(title.parent.x, fixtureConfig.panelPadding + (data.type === "dmenu" ? 0 : 26 + fixtureConfig.spacingControl));
            compare(title.parent.spacing, 0);
            verify(title.parent.implicitHeight <= row.height);
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
            run_qml_tests(directory)
