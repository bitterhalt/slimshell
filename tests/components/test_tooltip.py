"""Exercise tooltip styling/timing with an offscreen Window, never a layer surface."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ToolTipTests(unittest.TestCase):
    def test_themed_tooltip_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix="shell-tooltip-") as directory:
            base = Path(directory)
            source = (ROOT / "components/ShellToolTip.qml").read_text()
            (base / "ShellToolTip.qml").write_text(source.replace("import Quickshell", 'import "."'))
            (base / "PopupWindow.qml").write_text('''import QtQuick
import QtQuick.Window
Window {
    property bool grabFocus: false
    property QtObject mask
    property real implicitWidth: 0
    property real implicitHeight: 0
    width: implicitWidth
    height: implicitHeight
    property PopupAnchor anchor: PopupAnchor {}
}
''')
            (base / "PopupAnchor.qml").write_text('''import QtQuick
QtObject {
    property Item item
    property int edges
    property int gravity
    property int adjustment
    property rect rect: Qt.rect(0, 0, 0, 0)
}
''')
            (base / "Region.qml").write_text('import QtQuick\nQtObject {}')
            (base / "qmldir").write_text(
                "singleton Edges 1.0 Edges.qml\nsingleton PopupAdjustment 1.0 PopupAdjustment.qml\n"
            )
            (base / "Edges.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { enum Values { Bottom = 8 } }')
            (base / "PopupAdjustment.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { enum Values { SlideX = 1, FlipY = 2 } }'
            )
            (base / "tst_tooltip.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    width: 500
    height: 500
    Item { id: fixtureAnchor; width: 28; height: 26 }
    QtObject {
        id: fixtureConfig
        property color bg: "#111111"
        property color fg: "#dddddd"
        property color border: "#665544"
        property int popupRadius: 4
        property string textFontFamily: "sans-serif"
        readonly property real fontSize: 10
    }
    Component {
        id: tooltipComponent
        ShellToolTip { config: fixtureConfig; anchorItem: fixtureAnchor; delay: 40; text: "Example" }
    }
    TestCase {
        name: "ShellToolTip"
        when: windowShown
        function test_delay_style_and_immediate_hide() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const tooltip = createTemporaryObject(tooltipComponent, host);
            tooltip.shown = true;
            verify(!tooltip.visible);
            tryCompare(tooltip, "visible", true);
            verify(!tooltip.grabFocus);
            compare(tooltip.anchor.rect.y, 32);
            const caption = findChild(tooltip.contentItem, "tooltipCaption");
            verify(caption !== null);
            compare(caption.color, fixtureConfig.fg);
            compare(caption.parent.color, fixtureConfig.bg);
            compare(caption.parent.border.color, fixtureConfig.border);
            compare(caption.parent.radius, fixtureConfig.popupRadius);
            compare(caption.textFormat, Text.PlainText);
            compare(caption.renderType, Text.NativeRendering);
            tooltip.shown = false;
            verify(!tooltip.visible);
            tooltip.shown = true;
            verify(!tooltip.visible);
            tooltip.shown = false;
            wait(60);
            verify(!tooltip.visible);
        }
        function test_short_hints_fit_one_line_and_width_resets_after_long_text() {
            const tooltip = createTemporaryObject(tooltipComponent, host);
            const caption = findChild(tooltip.contentItem, "tooltipCaption");
            tooltip.shown = true;
            tryCompare(tooltip, "visible", true);
            for (const text of ["Recording screen · Click to stop", "Swap languages and input/output"]) {
                tooltip.text = text;
                tryCompare(caption, "lineCount", 1);
                const shortWidth = tooltip.width;
                tooltip.text = "long application name ".repeat(40);
                tryVerify(() => caption.lineCount > 1);
                tooltip.text = text;
                tryCompare(tooltip, "width", shortWidth);
                tryCompare(caption, "lineCount", 1);
            }
            tooltip.text = "Microphone in use\\nBrowser\\nChat";
            tryCompare(caption, "lineCount", 3);
        }
        function test_wrapping_and_hidden_anchor() {
            const tooltip = createTemporaryObject(tooltipComponent, host);
            tooltip.text = "<b>literal application name</b> " + "long name ".repeat(40);
            tooltip.shown = true;
            tryCompare(tooltip, "visible", true);
            verify(tooltip.width <= 360);
            verify(tooltip.height > 32);
            fixtureAnchor.visible = false;
            verify(!tooltip.visible);
            fixtureAnchor.visible = true;
            tooltip.text = "";
            verify(!tooltip.visible);
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
