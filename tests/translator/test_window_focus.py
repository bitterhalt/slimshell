"""Exercise the real translator UI offscreen; processes and layer-shell are inert."""

from pathlib import Path
import re
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import copy_control_config, run_qml_tests


ROOT = Path(__file__).resolve().parents[2] / "translator"

TEST = r'''
import QtQuick
import QtTest
import "."
Item {
TranslatorWindow {
    id: dialog
    targetScreen: null
    popupMotion: QtObject {
        property bool shown: true
        property bool surfaceVisible: true
        property real contentOpacity: 1
        property real contentOffset: 0
        property real surfaceHeight: 0
    }
    config: ControlConfig {
        border: Qt.alpha(selectionBackground, 0.45)
        urgent: "#ff5555"
    }
    TestCase {
        name: "TranslatorKeyboardFocus"
        when: windowShown
        Component {
            id: hoverButtonComponent
            ShellButton { config: dialog.config; text: "Translate"; x: 10; y: 100 }
        }
        function test_button_hover_uses_selection_foreground() {
            const button = createTemporaryObject(hoverButtonComponent, dialog.contentItem);
            verify(button !== null);
            mouseMove(button, button.width / 2, button.height / 2);
            tryCompare(button, "hovered", true);
            compare(button.contentItem.color, dialog.config.selectionForeground);
            compare(button.background.color, dialog.config.selectionBackground);
            button.enabled = false;
            compare(button.contentItem.color, dialog.config.muted);
            verify(button.background.color !== dialog.config.selectionBackground);
        }
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop/);
            dialog.popupMotion.shown = true;
            dialog.picker = "";
            dialog.requestActivate();
            findChild(dialog.contentItem, "translatorSourceInput").text = "";
        }
        function test_source_accepts_keyboard() {
            const source = findChild(dialog.contentItem, "translatorSourceInput");
            tryCompare(source, "activeFocus", true);
            keyClick(Qt.Key_A);
            compare(source.text, "a");
        }
        function test_consistent_panel_insets_and_text_padding() {
            const header = findChild(dialog.contentItem, "translatorHeader");
            const footer = findChild(dialog.contentItem, "translatorFooter");
            const body = findChild(dialog.contentItem, "translatorBody");
            const source = findChild(dialog.contentItem, "translatorSourceInput");
            compare(header.x, dialog.config.panelPadding);
            compare(header.y, dialog.config.panelPadding);
            compare(header.spacing, dialog.config.spacingControl);
            compare(body.y - header.y - header.height, dialog.config.panelPadding);
            compare(body.x, header.x);
            compare(body.width, header.width);
            compare(body.y + body.height + dialog.config.spacingControl, footer.y);
            const sourceCard = findChild(dialog.contentItem, "translatorSourceCard");
            const outputCard = findChild(dialog.contentItem, "translatorOutputCard");
            const sourceScroll = findChild(dialog.contentItem, "translatorSourceScroll");
            const outputScroll = findChild(dialog.contentItem, "translatorOutputScroll");
            const separator = findChild(dialog.contentItem, "translatorFooterSeparator");
            for (const card of [sourceCard, outputCard]) {
                compare(card.color, Qt.alpha(dialog.config.selectionBackground, 0.05));
                compare(card.border.color, dialog.config.border);
                compare(card.radius, 5);
            }
            compare(sourceCard.height, outputCard.height);
            compare(sourceScroll.height, Math.round(sourceScroll.height));
            compare(outputScroll.height, Math.round(outputScroll.height));
            compare(sourceScroll.y, Math.round(sourceScroll.y));
            compare(outputScroll.y, Math.round(outputScroll.y));
            compare(separator.x, dialog.config.panelPadding);
            compare(separator.width, footer.width - dialog.config.panelPadding * 2);
            compare(source.leftPadding, dialog.config.panelPadding);
            compare(source.topPadding, dialog.config.panelPadding);
            compare(footer.height, 28 + dialog.config.panelPadding * 2);
        }
        function test_reopening_during_exit_restores_input_focus() {
            const source = findChild(dialog.contentItem, "translatorSourceInput");
            dialog.popupMotion.shown = false;
            verify(!source.enabled);
            dialog.popupMotion.shown = true;
            tryCompare(source, "activeFocus", true);
            keyClick(Qt.Key_B);
            compare(source.text, "b");
        }
        function test_picker_search_accepts_keyboard() {
            dialog.openPicker("target");
            const search = findChild(dialog.contentItem, "translatorLanguageSearch");
            tryCompare(search, "activeFocus", true);
            keyClick(Qt.Key_F);
            compare(search.text, "f");
            dialog.closePicker();
        }
    }
}
}
'''


class TranslatorFocusTests(unittest.TestCase):
    def test_offline_window_focus(self):
        with tempfile.TemporaryDirectory(prefix="translator-focus-") as directory:
            base = Path(directory)
            source = (ROOT / "TranslatorWindow.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell")
                               and line != 'import "../components"')
            source = re.sub(r"^\s*WlrLayershell\.keyboardFocus:[^\n]*\n\s*\?[^\n]*\n", "\n", source, flags=re.M)
            source = re.sub(r"^\s*WlrLayershell\.[^\n]*\n", "\n", source, flags=re.M)
            (base / "TranslatorWindow.qml").write_text('import "."\n' + source)
            (base / "Languages.js").write_text((ROOT / "Languages.js").read_text())
            (base / "PanelSeparator.qml").write_text((ROOT.parent / "components/PanelSeparator.qml").read_text())
            (base / "PanelSurface.qml").write_text((ROOT.parent / "components/PanelSurface.qml").read_text())
            (base / "ShellButton.qml").write_text((ROOT.parent / "components/ShellButton.qml").read_text())
            (base / "ShellToolTip.qml").write_text((ROOT.parent / "tests/fixtures/ShellToolTip.qml").read_text())
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function env(name) { return "/synthetic-home"; } }\n'
            )
            doubles = {
                "PanelWindow": '''Window {
                    property bool focusable: true
                    property real exclusiveZone: 0
                    property real implicitWidth: 0
                    property real implicitHeight: 0
                    width: implicitWidth
                    height: implicitHeight
                    property PanelAnchors anchors: PanelAnchors {}
                    property PanelLayout margins: PanelLayout {}
                }''',
                "PanelLayout": '''QtObject {
                    property real top: 0
                    property real left: 0
                }''',
                "PanelAnchors": '''QtObject {
                    property bool top: false
                    property bool left: false
                }''',
                "PopupCatcher": '''QtObject {
                    property var targetScreen
                    property bool visible
                    signal dismissed()
                }''',
                "Process": '''QtObject {
                    property bool running: false
                    property bool stdinEnabled: false
                    property var command: []
                    property var environment: ({})
                    property QtObject stdout
                    property QtObject stderr
                    function write(value) { throw new Error("Unexpected process input"); }
                    function signal(number) {}
                    signal started()
                    signal exited(int exitCode)
                }''',
                "StdioCollector": '''QtObject {
                    property string text: ""
                    signal streamFinished()
                }''',
            }
            for name, body in doubles.items():
                (base / f"{name}.qml").write_text("import QtQuick\nimport QtQuick.Window\n" + body)
            copy_control_config(base)
            (base / "tst_focus.qml").write_text(TEST)
            run_qml_tests(directory, timeout=30)
