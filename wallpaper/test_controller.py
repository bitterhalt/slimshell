"""Check wallpaper helper arguments without running ImageMagick or awww."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent

TEST = '''import QtQuick
import QtTest
import "."
Item {
    id: host
    QtObject {
        id: fixtureConfig
        property int popupOpenDuration: 100
        property int popupCloseDuration: 70
        property real popupSlideDistance: 8
        property bool popupAnimations: false
        property string popupAnimationStyle: "fade"
    }
    QtObject {
        id: preferences
        property string hellwalMode: "dark"
        property real hellwalDarkOffset: 0.2
        property real hellwalBrightOffset: 0
        property real hellwalGrayScale: 0.35
        property string hellwalBackgroundMode: "dynamic"
        property string hellwalBackgroundColor: "#223344"
    }
    Component {
        id: controllerComponent
        Wallpaper { config: fixtureConfig; targetScreen: null; settingsService: preferences }
    }
    TestCase {
        name: "WallpaperApplyPreferences"
        function test_background_argument_data() {
            return [
                {tag: "dynamic", mode: "dynamic", hellwal: true, fixed: false},
                {tag: "fixed", mode: "fixed", hellwal: true, fixed: true},
                {tag: "plain-wallpaper", mode: "fixed", hellwal: false, fixed: false}
            ];
        }
        function test_background_argument(data) {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            preferences.hellwalBackgroundMode = data.mode;
            const controller = createTemporaryObject(controllerComponent, host);
            controller.apply("/synthetic/photo.png", data.hellwal);
            const process = Array.from(controller.data).find(child => child.command !== undefined);
            verify(process.running);
            const index = process.command.indexOf("--static-background");
            compare(index !== -1, data.fixed);
            if (data.fixed)
                compare(process.command[index + 1], "#223344");
            compare(process.command.indexOf("--hellwal") !== -1, data.hellwal);
            const grayIndex = process.command.indexOf("--gray-scale");
            compare(grayIndex !== -1, data.hellwal);
            if (data.hellwal)
                compare(process.command[grayIndex + 1], "0.35");
        }
    }
}
'''


class WallpaperControllerTests(unittest.TestCase):
    def test_apply_preferences(self):
        with tempfile.TemporaryDirectory(prefix="wallpaper-controller-") as directory:
            base = Path(directory)
            source = (ROOT / "Wallpaper.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import Quickshell")
                               and line not in ('import "../components"', 'import "../menus"'))
            (base / "Wallpaper.qml").write_text('import "."\n' + source)
            (base / "PopupMotion.qml").write_text((ROOT.parent / "components/PopupMotion.qml").read_text())
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject { function env(name) { return "/synthetic-home"; } }\n'
            )
            doubles = {
                "LazyLoader": "QtObject { default property Component component; property bool active: false }",
                "IpcHandler": "QtObject { property string target }",
                "WallpaperMenu": '''QtObject {
                    required property var config
                    required property var targetScreen
                    required property var controller
                    required property var popupMotion
                    signal closeRequested()
                }''',
                "Process": '''QtObject {
                    property bool running: false
                    property var command: []
                    property QtObject stdout
                    property QtObject stderr
                    signal exited(int exitCode)
                }''',
                "StdioCollector": 'QtObject { property string text: ""; signal streamFinished() }',
            }
            for name, body in doubles.items():
                (base / f"{name}.qml").write_text("import QtQuick\n" + body)
            (base / "tst_controller.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
