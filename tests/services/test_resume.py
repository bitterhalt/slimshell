"""Resume signals and real bar-clock wiring, with inert D-Bus and clock objects."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import copy_control_config, run_qml_tests

ROOT = Path(__file__).resolve().parents[2]


class ResumeTests(unittest.TestCase):
    def test_logind_signals_refresh_bar_clock(self):
        with tempfile.TemporaryDirectory(prefix="resume-clock-") as directory:
            base = Path(directory)
            source = (ROOT / "services/ResumeService.qml").read_text()
            (base / "ResumeService.qml").write_text(source.replace("import Quickshell.Io", 'import "."'))
            source = (ROOT / "bar/modules/clock/Clock.qml").read_text()
            source = source.replace("import Quickshell", 'import "."')
            source = source.replace('import "../../../components"', '').replace('import "../../../weather"', '')
            (base / "Clock.qml").write_text(source)
            (base / "ItemRevealer.qml").write_text((ROOT / "components/ItemRevealer.qml").read_text())
            doubles = {
                "Process": '''QtObject {
                    property bool running: false
                    property var command: []
                    property QtObject stdout
                    property QtObject stderr
                    signal exited(int exitCode)
                }''',
                "SplitParser": 'QtObject { signal read(string data) }',
                "StdioCollector": 'QtObject {}',
                "WeatherPopup": '''Item {
                    required property var config
                    required property var weatherData
                    signal closeRequested()
                }''',
                "SystemClock": '''QtObject {
                    enum Precision { Minutes }
                    property int precision
                    property bool enabled: true
                    property int refreshes: 0
                    property date date: new Date(2026, 10, 3)
                    onEnabledChanged: if (enabled) refreshes++
                }''',
            }
            for name, body in doubles.items():
                (base / f"{name}.qml").write_text("import QtQuick\n" + body)
            copy_control_config(base)
            (base / "tst_resume.qml").write_text('''import QtQuick
import QtTest
import "."
Item {
    id: host
    ControlConfig {
        id: fixtureConfig
        fg: "white"
        selectionBackground: "orange"
        property string clockFormat: "HH:mm"
        property string clockAlternativeFormat: "dddd, d MMMM"
    }
    QtObject { id: fixtureBar; property int height: 30; property var screen: null }
    QtObject {
        id: fixtureUi
        property var targetScreen: null
        signal weatherActionRequested(string action)
    }
    QtObject { id: fixtureWeather; property string text: "5°C"; property var data: ({available: true, temperature: 5}) }
    ResumeService { id: service }
    Clock {
        id: barClock
        config: fixtureConfig
        barWindow: fixtureBar
        uiService: fixtureUi
        weatherData: fixtureWeather
        popupManager: null
        resumeService: service
    }
    SignalSpy { id: resumeSpy; target: service; signalName: "resumed" }
    TestCase {
        name: "ResumeClock"
        readonly property string header: "signal time=1 sender=:1.1 -> destination=(null destination) serial=1 path=/org/freedesktop/login1; interface=org.freedesktop.login1.Manager; member=PrepareForSleep"
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            service.awaitingSleepState = false;
            resumeSpy.clear();
        }
        function test_only_resume_refreshes_minute_clock() {
            const process = findChild(service, "resumeMonitor");
            const clock = findChild(barClock, "barClock");
            verify(process.running);
            compare(process.command[0], "dbus-monitor");
            verify(process.command[2].includes("member='PrepareForSleep'"));
            const previous = clock.refreshes;
            process.stdout.read(header);
            process.stdout.read("   boolean true");
            compare(resumeSpy.count, 0);
            compare(clock.refreshes, previous);
            process.stdout.read(header);
            process.stdout.read("   boolean false");
            compare(resumeSpy.count, 1);
            compare(clock.refreshes, previous + 1);
            verify(clock.enabled);
            compare(clock.precision, 0);
        }
        function test_unrelated_or_partial_signals_are_ignored() {
            service.handleLine("   boolean false");
            service.handleLine("signal member=Unrelated");
            service.handleLine("   boolean false");
            compare(resumeSpy.count, 0);
            service.handleLine(header);
            service.handleLine("   boolean false");
            service.handleLine("   boolean false");
            compare(resumeSpy.count, 1);
        }
        function test_disconnect_clears_partial_message() {
            service.handleLine(header);
            findChild(service, "resumeMonitor").exited(1);
            service.handleLine("   boolean false");
            compare(resumeSpy.count, 0);
        }
    }
}
''')
            run_qml_tests(directory)
