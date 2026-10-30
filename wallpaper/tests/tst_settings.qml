import QtQuick
import QtQuick.Controls.Basic
import QtTest
import ".."

Item {
    id: host
    width: 660
    height: 500

    QtObject {
        id: fixtureConfig
        property color bg: "#111111"
        property color fg: "#eeeeee"
        property color muted: "#aaaaaa"
        property color urgent: "#ff5555"
        property color selectionBackground: "#6699cc"
        property color selectionForeground: "#ffffff"
        property color border: "#444444"
        function fontSize(scale) { return 10 * scale; }
    }
    QtObject {
        id: preferences
        property string hellwalMode: "dark"
        property real hellwalDarkOffset: 0.2
        property real hellwalBrightOffset: 0
        property real hellwalGrayScale: 0
        property string hellwalBackgroundMode: "dynamic"
        property string hellwalBackgroundColor: "#111111"
        property var calls: []
        function saveHellwalSettings(mode, dark, bright, background, color, grayScale) {
            if (background === "fixed" && !/^#[0-9a-fA-F]{6}$/.test(color))
                return "Enter a hex color like #111111";
            calls = calls.concat([{mode: mode, dark: dark, bright: bright,
                background: background, color: color, grayScale: grayScale}]);
            return "";
        }
    }
    Component {
        id: settingsComponent
        WallpaperSettings {
            config: fixtureConfig
            settingsService: preferences
            busy: false
            width: 620
            height: 400
        }
    }

    TestCase {
        name: "WallpaperSettings"
        when: windowShown
        property var panel: null
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            preferences.calls = [];
            panel = createTemporaryObject(settingsComponent, host);
            verify(panel !== null);
            panel.begin();
        }
        function test_fixed_mode_saves_color_with_other_settings() {
            const background = findChild(panel, "wallpaperBackgroundMode");
            const color = findChild(panel, "wallpaperBackgroundColor");
            compare(background.currentIndex, 0);
            verify(!color.enabled);
            verify(color.visible);
            background.currentIndex = 1;
            verify(color.enabled);
            verify(color.visible);
            color.text = "#223344";
            panel.save();
            compare(preferences.calls.length, 1);
            compare(preferences.calls[0].background, "fixed");
            compare(preferences.calls[0].color, "#223344");
            compare(preferences.calls[0].dark, 0.2);
            compare(preferences.calls[0].grayScale, 0);
        }
        function test_cancel_does_not_save_draft() {
            findChild(panel, "wallpaperBackgroundMode").currentIndex = 1;
            findChild(panel, "wallpaperBackgroundColor").text = "#223344";
            panel.cancelled();
            compare(preferences.calls.length, 0);
            panel.begin();
            compare(findChild(panel, "wallpaperBackgroundMode").currentIndex, 0);
            compare(findChild(panel, "wallpaperBackgroundColor").text, "#111111");
        }
        function test_invalid_color_keeps_settings_open() {
            findChild(panel, "wallpaperBackgroundMode").currentIndex = 1;
            findChild(panel, "wallpaperBackgroundColor").text = "bad";
            panel.save();
            verify(panel.errorText !== "");
            compare(preferences.calls.length, 0);
        }
        function test_keyboard_can_switch_modes_and_save() {
            const mode = findChild(panel, "wallpaperColorMode");
            tryCompare(mode, "activeFocus", true);
            keyClick(Qt.Key_Down);
            compare(mode.currentIndex, 1);
            keyClick(Qt.Key_Tab);
            const background = findChild(panel, "wallpaperBackgroundMode");
            tryCompare(background, "activeFocus", true);
            keyClick(Qt.Key_Down);
            compare(background.currentIndex, 1);
            keyClick(Qt.Key_Return, Qt.ControlModifier);
            compare(preferences.calls.length, 1);
            compare(preferences.calls[0].mode, "light");
            compare(preferences.calls[0].background, "fixed");
        }
        function test_control_widths_stay_constant_when_text_changes() {
            const background = findChild(panel, "wallpaperBackgroundMode");
            const mode = findChild(panel, "wallpaperColorMode");
            const color = findChild(panel, "wallpaperBackgroundColor");
            wait(50);
            const backgroundWidth = background.width;
            const modeWidth = mode.width;
            const colorWidth = color.width;
            background.currentIndex = 1;
            mode.currentIndex = 1;
            color.text = "";
            findChild(panel, "wallpaperDarkOffset").text = "";
            wait(50);
            compare(background.width, backgroundWidth);
            compare(mode.width, modeWidth);
            compare(color.width, colorWidth);
            background.currentIndex = -1;
            wait(50);
            compare(background.width, backgroundWidth);
        }

        function test_narrow_layout_keeps_fields_inside_panel() {
            findChild(panel, "wallpaperBackgroundMode").currentIndex = 1;
            panel.width = 300;
            waitForPolish(panel);
            for (const name of ["wallpaperColorMode", "wallpaperBackgroundMode",
                    "wallpaperDarkOffset", "wallpaperBrightOffset", "wallpaperGrayScale",
                    "wallpaperBackgroundColor"]) {
                const control = findChild(panel, name);
                tryVerify(() => {
                    const position = control.mapToItem(panel, 0, 0);
                    return position.x >= 0 && position.x + control.width <= panel.width + 1;
                }, 1000, name + " must fit within the panel");
            }
        }
    }
}
