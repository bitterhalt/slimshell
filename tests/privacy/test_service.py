"""Observe real privacy bindings with inert PipeWire objects, never live capture."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PrivacyServiceTests(unittest.TestCase):
    def test_link_state_and_properties_update_service(self):
        with tempfile.TemporaryDirectory(prefix="privacy-service-") as directory:
            base = Path(directory)
            source = (ROOT / "services/PrivacyService.qml").read_text()
            source = source.replace("import Quickshell.Services.Pipewire", 'import "."')
            source = source.replace('"privacy/Model.js"', '"Model.js"')
            (base / "PrivacyService.qml").write_text(source)
            (base / "Model.js").write_text((ROOT / "services/privacy/Model.js").read_text())
            (base / "qmldir").write_text(
                "singleton Pipewire 1.0 Pipewire.qml\nsingleton PwLinkState 1.0 PwLinkState.qml\n"
            )
            (base / "Pipewire.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property QtObject nodes: QtObject { property var values: [] }
    property QtObject linkGroups: QtObject { property var values: [] }
}
''')
            (base / "PwLinkState.qml").write_text('''pragma Singleton
import QtQuick
QtObject { enum State { Paused, Active } }
''')
            (base / "PwObjectTracker.qml").write_text('''import QtQuick
QtObject { objectName: "privacyTracker"; property var objects: [] }
''')
            (base / "tst_service.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    QtObject {
        id: microphone
        property var audio: ({})
        property bool isSink: false
        property bool isStream: false
        property var properties: ({})
    }
    QtObject {
        id: application
        property var audio: ({})
        property bool isStream: true
        property var properties: ({"media.class": "Stream/Input/Audio", "application.name": "Chat"})
    }
    QtObject {
        id: link
        property var source: microphone
        property var target: application
        property int state: PwLinkState.Paused
    }
    Component { id: serviceComponent; PrivacyService {} }
    TestCase {
        name: "PrivacyService"
        function test_reacts_to_active_links_properties_and_removal() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const service = createTemporaryObject(serviceComponent, host);
            verify(!service.microphoneActive);
            Pipewire.nodes.values = [microphone, application];
            Pipewire.linkGroups.values = [link];
            compare(findChild(service, "privacyTracker").objects.length, 3);
            verify(!service.microphoneActive);
            link.state = PwLinkState.Active;
            verify(service.microphoneActive);
            compare(service.microphoneApplications, ["Chat"]);
            application.properties = {"media.class": "Stream/Input/Audio", "application.name": "Browser"};
            compare(service.microphoneApplications, ["Browser"]);
            link.state = PwLinkState.Paused;
            verify(!service.microphoneActive);
            link.state = PwLinkState.Active;
            Pipewire.linkGroups.values = [];
            verify(!service.microphoneActive);
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
