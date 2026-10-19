"""Test the eager controller with loader/panel/IPC doubles, without a live shell.

Quickshell's plugins are linked into qs, so qmltestrunner cannot load them.
Only the imports are removed from the controller copy; its logic is unchanged.
The doubles never launch cliphist, create a window, or touch clipboard history.
"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


CONTROLLER = Path(__file__).resolve().parents[1] / "Clipboard.qml"
LOADER = '''import QtQuick
Item {
    id: root
    default property Component component
    property bool active: false
    readonly property var item: loader.item
    Loader {
        id: loader
        active: root.active
        sourceComponent: root.component
    }
}
'''
PANEL = '''import QtQuick
QtObject {
    id: root
    required property var config
    required property var targetScreen
    property bool opened: false
    Component.onCompleted: { config.created++; config.panel = root; }
    function open() { opened = true; config.opens++; }
    function close() { opened = false; config.closes++; }
    function refresh() { config.refreshes++; }
    function copySelected() { config.copies++; }
    function deleteSelected() { config.deletes++; }
}
'''
IPC = '''import QtQuick
QtObject {
    property string target
    objectName: target
}
'''
TEST = '''import QtQuick
import QtTest
Item {
    id: host
    QtObject {
        id: fixture
        property int created: 0
        property int opens: 0
        property int closes: 0
        property int refreshes: 0
        property int copies: 0
        property int deletes: 0
        property var panel: null
        property var screen: ({name: "first"})
    }
    Component {
        id: controllerComponent
        Clipboard { config: fixture; targetScreen: fixture.screen }
    }
    TestCase {
        name: "LazyClipboardController"
        property var controller: null
        function init() {
            fixture.created = fixture.opens = fixture.closes = 0;
            fixture.refreshes = fixture.copies = fixture.deletes = 0;
            fixture.panel = null;
            controller = createTemporaryObject(controllerComponent, host);
            verify(controller !== null);
        }
        function test_initially_unloaded() {
            verify(!controller.opened);
            controller.close();
            controller.refresh();
            controller.copySelected();
            controller.deleteSelected();
            compare(fixture.created, 0);
        }
        function test_open_and_reuse() {
            controller.open();
            verify(controller.opened);
            compare(fixture.created, 1);
            controller.close();
            verify(!controller.opened);
            controller.toggle();
            verify(controller.opened);
            controller.toggle();
            verify(!controller.opened);
            compare(fixture.created, 1);
            compare(fixture.opens, 2);
        }
        function test_panel_close_updates_controller() {
            controller.open();
            fixture.panel.close();
            verify(!controller.opened);
            controller.toggle();
            verify(controller.opened);
            compare(fixture.created, 1);
        }
        function test_ipc_and_forwarded_actions() {
            const ipc = findChild(controller, "clipboard");
            verify(ipc !== null);
            compare(fixture.created, 0);
            ipc.open();
            verify(controller.opened);
            ipc.refresh();
            ipc.copySelected();
            ipc.deleteSelected();
            compare(fixture.refreshes, 1);
            compare(fixture.copies, 1);
            compare(fixture.deletes, 1);
            ipc.toggle();
            verify(!controller.opened);
        }
        function test_screen_binding_survives_loading() {
            controller.open();
            fixture.screen = {name: "second"};
            compare(fixture.panel.targetScreen.name, "second");
        }
    }
}
'''


class LazyClipboardTests(unittest.TestCase):
    def test_controller_contract(self):
        source = CONTROLLER.read_text()
        source = source.replace("import Quickshell\n", "")
        source = source.replace("import Quickshell.Io\n", "")
        with tempfile.TemporaryDirectory(prefix="clipboard-controller-") as folder:
            base = Path(folder)
            for name, text in {
                "Clipboard.qml": source, "ClipboardPanel.qml": PANEL,
                "LazyLoader.qml": LOADER, "IpcHandler.qml": IPC,
                "tst_controller.qml": TEST,
            }.items():
                (base / name).write_text(text)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", folder, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
