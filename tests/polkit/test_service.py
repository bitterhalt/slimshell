"""Test prompt/service wiring with an inert agent and offscreen windows."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PolkitServiceTests(unittest.TestCase):
    def test_prompt_intents_clear_and_route_responses(self):
        with tempfile.TemporaryDirectory(prefix="polkit-service-") as directory:
            base = Path(directory)
            source = (ROOT / "services/PolkitService.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell"))
            source = source.replace('import "../polkit"', 'import "."')
            source = "\n".join(line for line in source.splitlines()
                               if not line.strip().startswith("WlrLayershell."))
            (base / "PolkitService.qml").write_text(source)
            source = (ROOT / "polkit/PolkitPrompt.qml").read_text().replace('import "../components"', 'import "."')
            (base / "PolkitPrompt.qml").write_text(source)
            for name in ("PanelSurface.qml", "ShellButton.qml", "ShellTextField.qml"):
                (base / name).write_text((ROOT / "components" / name).read_text())
            (base / "ControlConfig.qml").write_text((ROOT / "tests/components/ControlConfig.qml").read_text())
            (base / "Scope.qml").write_text("import QtQuick\nItem {}")
            (base / "PolkitAgent.qml").write_text('''import QtQuick
QtObject {
    objectName: "mockPolkitAgent"
    property var flow: null
    property bool isActive: false
}
''')
            (base / "PanelWindow.qml").write_text('''import QtQuick
Window {
    property bool focusable: true
    property real exclusiveZone: 0
    property real implicitWidth: 0
    property real implicitHeight: 0
    width: implicitWidth
    height: implicitHeight
    property PanelAnchors anchors: PanelAnchors {}
    property PanelLayout margins: PanelLayout {}
}
''')
            (base / "PanelAnchors.qml").write_text("import QtQuick\nQtObject { property bool top: false; property bool left: false }")
            (base / "PanelLayout.qml").write_text("import QtQuick\nQtObject { property real top: 0; property real left: 0 }")
            (base / "tst_service.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    ControlConfig { id: fixtureConfig }
    QtObject {
        id: fixtureFlow
        property string message: "Synthetic authentication"
        property string actionId: "test.action"
        property var identities: [{displayName: "One"}, {displayName: "Two"}]
        property var selectedIdentity: identities[0]
        property bool isResponseRequired: true
        property bool responseVisible: false
        property string inputPrompt: "Password"
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        property string receivedResponse: ""
        property int cancellations: 0
        function submit(value) { receivedResponse = value; }
        function cancelAuthenticationRequest() { cancellations++; }
    }
    Component { id: serviceComponent; PolkitService { config: fixtureConfig; targetScreen: null } }
    TestCase {
        name: "PolkitServiceViewWiring"
        when: windowShown
        function test_routes_and_clears_without_real_authentication() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const service = createTemporaryObject(serviceComponent, host);
            const agent = findChild(service, "mockPolkitAgent");
            agent.flow = fixtureFlow;
            agent.isActive = true;
            const field = findChild(service, "polkitResponseField");
            const picker = findChild(service, "polkitIdentityPicker");
            const submit = findChild(service, "polkitSubmitButton");
            const cancel = findChild(service, "polkitCancelButton");
            verify(field !== null);
            field.text = "discarded on identity switch";
            picker.activated(1);
            compare(fixtureFlow.selectedIdentity, fixtureFlow.identities[1]);
            compare(field.text, "");
            field.text = "synthetic-response";
            submit.clicked();
            compare(fixtureFlow.receivedResponse, "synthetic-response");
            compare(field.text, "");
            field.text = "discarded on cancel";
            cancel.clicked();
            compare(fixtureFlow.cancellations, 1);
            compare(field.text, "");
            field.text = "discarded on flow change";
            agent.flow = null;
            compare(field.text, "");
            agent.isActive = false;
            wait(0);
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
