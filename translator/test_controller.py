"""Test real lazy-loader/motion wiring without creating a translator surface."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class TranslatorControllerTests(unittest.TestCase):
    def test_motion_is_passed_through_lazy_loader(self):
        with tempfile.TemporaryDirectory(prefix="translator-controller-") as directory:
            base = Path(directory)
            source = (ROOT / "Translator.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell"))
            (base / "Translator.qml").write_text(source.replace('"../components"', '"."'))
            (base / "Languages.js").write_text((ROOT / "Languages.js").read_text())
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function env(name) { return "/synthetic-home"; } }\n'
            )
            (base / "PopupMotion.qml").write_text(
                (ROOT.parent / "components/PopupMotion.qml").read_text()
            )
            (base / "LazyLoader.qml").write_text('''import QtQuick
Item {
    id: root
    default property Component component
    property bool active: false
    readonly property var item: loader.item
    Loader { id: loader; active: root.active; sourceComponent: root.component }
}
''')
            (base / "IpcHandler.qml").write_text(
                'import QtQuick\nQtObject { property string target }\n'
            )
            (base / "FileView.qml").write_text('''import QtQuick
QtObject {
    property string path: ""
    property bool atomicWrites: false
    property bool printErrors: false
    property string contents: ""
    property string written: ""
    signal loaded()
    signal loadFailed()
    function text() { return contents; }
    function setText(value) { written = value; }
}
''')
            (base / "TranslatorWindow.qml").write_text('''import QtQuick
Item {
    required property var config
    required property var targetScreen
    required property var popupMotion
    property string sourceLanguage: ""
    property string targetLanguage: "EN-GB"
    readonly property bool keyboardRequested: !!popupMotion && popupMotion.shown
    signal closeRequested()
}
''')
            (base / "tst_controller.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    QtObject {
        id: settings
        property int popupOpenDuration: 5
        property int popupCloseDuration: 5
        property real popupSlideDistance: 8
        property bool popupAnimations: true
        property string popupAnimationStyle: "fade"
    }
    Component { id: controllerComponent; Translator { config: settings; targetScreen: null } }
    TestCase {
        name: "TranslatorMotionWiring"
        when: windowShown
        function test_lazy_window_receives_motion_and_requests_keyboard() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const controller = createTemporaryObject(controllerComponent, host);
            verify(controller !== null);
            const loader = controller.children.find(child => child.item !== undefined);
            verify(loader !== undefined);
            compare(loader.item, null);
            controller.open();
            tryVerify(() => loader.item !== null);
            verify(loader.item.popupMotion !== undefined);
            verify(loader.item.keyboardRequested);
            const window = loader.item;
            controller.close();
            verify(!window.keyboardRequested);
            controller.open();
            compare(loader.item, window);
            verify(window.keyboardRequested);
            controller.close();
            tryCompare(loader, "item", null);
        }
        function test_language_preferences_restore_and_persist_only_codes() {
            const controller = createTemporaryObject(controllerComponent, host);
            const file = findChild(controller, "translatorLanguagePreferences");
            verify(file !== undefined);
            file.contents = JSON.stringify({source: "SV", target: "EN-US"});
            file.loaded();
            compare(controller.sourceLanguage, "SV");
            compare(controller.targetLanguage, "EN-US");
            compare(file.written, "");
            controller.sourceLanguage = "DE";
            controller.targetLanguage = "FR";
            compare(JSON.parse(file.written), {source: "DE", target: "FR"});
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
