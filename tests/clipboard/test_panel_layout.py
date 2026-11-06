"""Render the real clipboard panel with inert processes and offscreen windows."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import copy_control_config, run_qml_tests

ROOT = Path(__file__).resolve().parents[2]


class ClipboardLayoutTests(unittest.TestCase):
    def test_panel_spacing_and_border_insets(self):
        with tempfile.TemporaryDirectory(prefix="clipboard-layout-") as directory:
            base = Path(directory)
            source = (ROOT / "clipboard/ClipboardPanel.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell")
                               and line != 'import "../components"'
                               and not line.strip().startswith("WlrLayershell."))
            (base / "ClipboardPanel.qml").write_text('import "."\n' + source)
            for name in ("ClipboardPreview.qml", "ClipboardHistoryRow.qml"):
                (base / name).write_text((ROOT / "clipboard" / name).read_text())
            (base / "PanelSeparator.qml").write_text((ROOT / "components/PanelSeparator.qml").read_text())
            (base / "PopupMotion.qml").write_text((ROOT / "components/PopupMotion.qml").read_text())
            copy_control_config(base)
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            doubles = {
                "Quickshell": '''pragma Singleton
import QtQuick
QtObject {
    property int processId: 42
    function env(name) { return "/synthetic-runtime"; }
}''',
                "PanelWindow": '''import QtQuick
Window {
    property bool focusable: true
    property real exclusiveZone: 0
    property PanelAnchors anchors: PanelAnchors {}
    width: 1000
    height: 700
}''',
                "PanelAnchors": '''import QtQuick
QtObject {
    property bool top: false
    property bool bottom: false
    property bool left: false
    property bool right: false
}''',
                "Process": '''import QtQuick
Item {
    property var command: []
    property bool running: false
    property QtObject stdout: null
    signal exited(int exitCode, int exitStatus)
    function signal(number) {}
}''',
                "StdioCollector": '''import QtQuick
QtObject {
    property string text: ""
    signal streamFinished
}''',
            }
            for name, contents in doubles.items():
                (base / f"{name}.qml").write_text(contents)
            (base / "tst_layout.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    ControlConfig { id: fixtureConfig }
    Component { id: panelComponent; ClipboardPanel { config: fixtureConfig; targetScreen: null } }
    TestCase {
        name: "ClipboardPanelSpacing"
        when: windowShown
        function test_header_footer_list_and_preview_insets() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const window = createTemporaryObject(panelComponent, host);
            window.opened = true;
            waitForPolish(window);
            const surface = findChild(window.contentItem, "clipboardSurface");
            const frame = findChild(surface, "clipboardSearchFrame");
            const header = findChild(surface, "clipboardHeader");
            const footer = findChild(surface, "clipboardFooter");
            const entries = findChild(surface, "clipboardEntries");
            const body = findChild(surface, "clipboardBody");
            const preview = findChild(surface, "clipboardPreviewCard");
            const separator = findChild(surface, "clipboardFooterSeparator");
            compare(header.x + frame.x, fixtureConfig.panelPadding);
            compare(surface.width - header.x - frame.x - frame.width, fixtureConfig.panelPadding);
            compare(header.y + frame.y, fixtureConfig.panelPadding);
            compare(entries.x, 0);
            compare(body.x, fixtureConfig.panelPadding);
            compare(preview.x - entries.parent.width, fixtureConfig.spacingControl);
            compare(body.y + body.height + fixtureConfig.spacingControl, footer.y);
            compare(separator.x, fixtureConfig.panelPadding);
            compare(separator.width, footer.width - fixtureConfig.panelPadding * 2);
            compare(entries.spacing, fixtureConfig.spacingTight);
            compare(footer.x, 0);
            compare(surface.height - footer.y - footer.height, 0);
            verify(footer.height > fixtureConfig.panelPadding * 2);
        }
    }
}
''')
            run_qml_tests(directory)
