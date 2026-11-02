"""Exercise the shared service with inert process objects."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class WeatherServiceTests(unittest.TestCase):
    def test_offline_service(self):
        with tempfile.TemporaryDirectory(prefix="weather-service-") as directory:
            base = Path(directory)
            source = (ROOT / "services/WeatherService.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell"))
            (base / "WeatherService.qml").write_text('import "."\n' + source)
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function env(name) { return "/synthetic-home"; } }'
            )
            (base / "Process.qml").write_text('''import QtQuick
QtObject {
    property bool running: false
    property var command: []
    property QtObject stdout
    property QtObject stderr
    signal exited(int exitCode)
}
''')
            (base / "StdioCollector.qml").write_text('''import QtQuick
QtObject { property string text: ""; signal streamFinished() }
''')
            (base / "tst_service.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    Component { id: serviceComponent; WeatherService {} }
    TestCase {
        name: "WeatherService"
        function test_refresh_reply_and_errors() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const service = createTemporaryObject(serviceComponent, host);
            const process = findChild(service, "weatherProcess");
            verify(process !== null);
            process.running = false;
            service.refresh(true);
            verify(service.refreshing);
            compare(process.command[0], "python3");
            compare(process.command[2], "--refresh");
            service.refresh(false);
            compare(process.command[2], "--refresh");
            process.stdout.text = JSON.stringify({available: true, text: "12°C", forecast: []});
            process.stdout.streamFinished();
            compare(service.text, "12°C");
            verify(service.data.available);
            process.running = false;
            service.refresh(false);
            compare(process.command.length, 2);
            process.stdout.text = "broken";
            process.stdout.streamFinished();
            verify(!service.data.available);
            compare(service.text, "⚠ N/A");
            process.running = false;
            service.refresh(false);
            process.exited(1);
            verify(!service.data.available);
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
