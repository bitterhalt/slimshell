"""Test lock-screen feedback with an inert context; never start PAM or lock."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

TEST = '''import QtQuick
import QtTest
import "."
Item {
    id: host
    width: 800
    height: 700
    QtObject {
        id: fixtureConfig
        property color bg: "#111111"
        property color fg: "#eeeeee"
        property color muted: "#888888"
        property color urgent: "#ff4444"
        property color selectionBackground: "#6699cc"
        property color border: "#446688"
        property color selectionForeground: "white"
    }
    QtObject {
        id: auth
        property string currentText: ""
        property bool acceptingPassword: true
        property bool pamResponseRequired: true
        property bool pamActivated: true
        property bool showFailure: false
        property bool unlockInProgress: false
        property string errorText: ""
        property bool pamMessageIsError: false
        property string pamMessage: ""
        property int submissions: 0
        function requestUnlock() { pamActivated = true; }
        function tryUnlock() { showFailure = false; }
        function cancelPam() { pamActivated = false; currentText = ""; }
        function submitPassword() {
            if (!acceptingPassword) return;
            submissions++;
            acceptingPassword = false;
            unlockInProgress = true;
        }
    }
    Component {
        id: surfaceComponent
        LockSurface { context: auth; config: fixtureConfig; width: host.width; height: host.height }
    }
    TestCase {
        name: "LockFeedback"
        when: windowShown
        property var surface: null
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            auth.currentText = "";
            auth.pamActivated = auth.pamResponseRequired = auth.acceptingPassword = true;
            auth.showFailure = auth.unlockInProgress = auth.pamMessageIsError = false;
            auth.errorText = auth.pamMessage = "";
            auth.submissions = 0;
            surface = createTemporaryObject(surfaceComponent, host);
            surface.focusPassword();
        }
        function test_typing_backspace_and_submit() {
            const input = findChild(surface, "lockPasswordInput");
            const dots = findChild(surface, "lockPasswordDots");
            tryCompare(input, "activeFocus", true);
            compare(dots.count, 0);
            keyClick(Qt.Key_A);
            keyClick(Qt.Key_B);
            compare(auth.currentText, "ab");
            compare(dots.count, 2);
            compare(findChild(surface, "lockPasswordDot-0").color, fixtureConfig.border);
            compare(findChild(surface, "lockPasswordDot-1").color, fixtureConfig.selectionBackground);
            compare(input.color.a, 0);
            verify(input.cursorDelegate !== null);
            keyClick(Qt.Key_Backspace);
            compare(dots.count, 1);
            keyClick(Qt.Key_Return);
            compare(auth.submissions, 1);
        }
        function test_feedback_is_bounded_and_clears() {
            const dots = findChild(surface, "lockPasswordDots");
            auth.currentText = "a".repeat(40);
            compare(dots.count, 12);
            auth.currentText = "";
            compare(dots.count, 0);
        }
        function test_weather_cache_is_optional_and_invalid_data_is_hidden() {
            const file = findChild(surface, "lockWeatherCache");
            const label = findChild(surface, "lockWeatherLabel");
            verify(!label.visible);
            file.contents = JSON.stringify({_place: "Oulu", current: {temperature_2m: 4.7}});
            file.loaded();
            compare(label.text, "Oulu 5°C");
            verify(label.visible);
            file.loadFailed();
            compare(label.text, "");
            verify(!label.visible);
            for (const value of ["broken", "null", "{}",
                    '{"_place":"Oulu","current":{"temperature_2m":null}}']) {
                file.contents = value;
                file.loaded();
                compare(label.text, "");
                verify(!label.visible);
            }
        }
        function test_pulse_settles_and_deletion_cancels_it() {
            auth.currentText = "a";
            tryVerify(() => surface.pulseScale > 1);
            tryCompare(surface, "pulseScale", 1);
            tryCompare(surface, "pulseOpacity", 0);
            auth.currentText = "ab";
            tryVerify(() => surface.pulseScale > 1);
            auth.currentText = "a";
            compare(surface.pulseScale, 1);
            compare(surface.pulseOpacity, 0);
            auth.currentText = "";
            compare(surface.previousPasswordLength, 0);
        }
        function test_failure_shake_settles_and_retry_resets() {
            auth.showFailure = true;
            tryVerify(() => surface.feedbackOffset !== 0);
            tryCompare(surface, "feedbackOffset", 0);
            auth.showFailure = false;
            auth.showFailure = true;
            tryVerify(() => surface.feedbackOffset !== 0);
            auth.showFailure = false;
            compare(surface.feedbackOffset, 0);
        }
        function test_plain_failure_and_error_colors() {
            const status = findChild(surface, "lockStatus");
            auth.showFailure = true;
            compare(status.text, "Incorrect password");
            compare(status.color, "#cc241d");
            auth.showFailure = false;
            auth.errorText = "Authentication error";
            compare(status.text, "Authentication error");
            compare(status.color, "#cc241d");
            auth.errorText = "";
            compare(status.text, "");
        }
        function test_typing_before_pam_prompt_keeps_feedback() {
            auth.pamResponseRequired = false;
            auth.unlockInProgress = true;
            surface.forceActiveFocus();
            keyClick(Qt.Key_A);
            compare(auth.currentText, "a");
            compare(findChild(surface, "lockPasswordDots").count, 1);
        }
    }
}
'''


class LockSurfaceTests(unittest.TestCase):
    def test_offline_feedback(self):
        with tempfile.TemporaryDirectory(prefix="lock-feedback-") as directory:
            base = Path(directory)
            source = (ROOT / "LockSurface.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell"))
            source = source.replace("required property LockContext context", "required property var context")
            source = re.sub(r'        source: "file://"[^\n]*', '        source: ""', source)
            (base / "LockSurface.qml").write_text('import "."\n' + source)
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function env(name) { return "/synthetic-home"; } }'
            )
            (base / "FileView.qml").write_text('''import QtQuick
QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool printErrors: true
    property string contents: ""
    signal loaded()
    signal loadFailed()
    signal fileChanged()
    function text() { return contents; }
    function reload() {}
}
''')
            (base / "SystemClock.qml").write_text('''import QtQuick
QtObject {
    enum Precision { Minutes }
    property int precision
    property date date: new Date(2026, 10, 2)
}
''')
            (base / "tst_surface.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
