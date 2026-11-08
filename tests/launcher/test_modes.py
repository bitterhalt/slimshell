"""Exercise Launcher mode-routing methods without applications, helpers or IPC."""
from pathlib import Path
import re
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import run_qml_tests

ROOT = Path(__file__).resolve().parents[2]


class LauncherModeTests(unittest.TestCase):
    def test_direct_mode_calls_and_dmenu_cancellation(self):
        source = (ROOT / "launcher/Launcher.qml").read_text()
        methods = []
        for name in ("reset", "close", "finalizeClose", "cancelDmenu", "openApplications",
                     "toggleApplications", "setMode", "toggleMode"):
            match = re.search(r"^    function " + name + r"\([^\n]*\{.*?^    }", source, re.M | re.S)
            self.assertIsNotNone(match, name)
            methods.append(match.group())
        for name in ("apps", "run", "emoji", "files", "calculator"):
            self.assertRegex(
                source,
                rf'function {name}\(\):\s*void\s*\{{\s*root\.toggleMode\("{name}"\);?\s*\}}',
            )
        self.assertRegex(source, r'function search\(\):\s*void\s*\{\s*root\.toggleMode\("files"\);?\s*\}')
        with tempfile.TemporaryDirectory(prefix="launcher-modes-") as directory:
            base = Path(directory)
            (base / "Controller.qml").write_text('''import QtQuick
Item {
    id: root
    property var modes: ["apps", "run", "emoji"]
    property string mode: "apps"
    property string query: ""
    property bool opened: false
    property bool quitOnClose: false
    property int selectedIndex: 0
    property int prunes: 0
    property alias input: searchInput
    readonly property bool dmenuMode: mode === "dmenu"
    readonly property bool fileMode: mode === "apps" && query.startsWith("/")
    readonly property bool calcPrefix: mode === "apps" && query.startsWith("=")
    property bool calculatorQuery: false
    property string dmenuOutPath: ""
    property var dmenuItems: []
    property string dmenuPrompt: ""
    property var writes: []
    TextInput { id: searchInput; onTextChanged: root.query = text }
    function writeDmenuOutput(path, value) { writes = writes.concat([{path: path, value: value}]); }
''' + "\n".join(methods) + "\n}\n")
            (base / "tst_modes.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    Component { id: controllerComponent; Controller {} }
    TestCase {
        name: "LauncherDirectModes"
        function test_open_switch_toggle_data() {
            return ["apps", "run", "emoji", "files", "calculator"].map(name => ({tag: name, name: name}));
        }
        function test_open_switch_toggle(data) {
            failOnWarning(/TypeError|ReferenceError|Binding loop/);
            const controller = createTemporaryObject(controllerComponent, host);
            controller.toggleMode(data.name);
            verify(controller.opened);
            compare(controller.mode, ["files", "calculator"].includes(data.name) ? "apps" : data.name);
            compare(controller.query, data.name === "files" ? "/" : data.name === "calculator" ? "=" : "");
            controller.toggleMode(data.name);
            verify(!controller.opened);
            controller.openApplications();
            controller.toggleMode(data.name);
            compare(controller.opened, data.name !== "apps");
        }
        function test_switches_and_releases_dmenu_caller() {
            const controller = createTemporaryObject(controllerComponent, host);
            controller.mode = "dmenu";
            controller.opened = true;
            controller.dmenuOutPath = "/synthetic/result";
            controller.dmenuItems = ["One", "Two"];
            controller.toggleMode("emoji");
            compare(controller.mode, "emoji");
            verify(controller.opened);
            compare(controller.writes.length, 1);
            compare(controller.writes[0].path, "/synthetic/result");
            compare(controller.writes[0].value, null);
            compare(controller.dmenuOutPath, "");
            compare(controller.dmenuItems.length, 0);
            controller.toggleMode("files");
            compare(controller.query, "/");
            controller.toggleMode("calculator");
            compare(controller.query, "=");
            controller.input.text = "=2+2";
            controller.toggleMode("calculator");
            verify(!controller.opened);
        }
        function test_existing_toggle_and_invalid_mode() {
            const controller = createTemporaryObject(controllerComponent, host);
            controller.toggleMode("emoji");
            controller.toggleMode("invalid");
            compare(controller.mode, "emoji");
            controller.toggleApplications();
            verify(!controller.opened);
            controller.toggleApplications();
            compare(controller.mode, "apps");
            verify(controller.opened);
        }
    }
}
''')
            run_qml_tests(directory)
