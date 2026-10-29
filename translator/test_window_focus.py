"""Exercise the real translator UI offscreen; processes and layer-shell are inert."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent

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
    }
    config: QtObject {
        property color bg: "#101010"
        property color fg: "#eeeeee"
        property color muted: "#888888"
        property color urgent: "#ff5555"
        property color selectionBackground: "#6699cc"
        property color selectionForeground: "#ffffff"
        property int popupGap: 16
        property int popupRadius: 4
        property string iconFontFamily: "sans-serif"
        property real iconSize: 10
        function fontSize(scale) { return 10 * scale; }
    }
    TestCase {
        name: "TranslatorKeyboardFocus"
        when: windowShown
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
            for name in ("TranslatorButton.qml", "Languages.js"):
                (base / name).write_text((ROOT / name).read_text())
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
            (base / "tst_focus.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
