import QtQuick
import QtTest
import ".."

Item {
    id: host
    width: 500
    height: 800

    QtObject {
        id: fixtureConfig
        property color fg: "white"
        property color muted: "gray"
        property color surface: "#151515"
        property color accent: "orange"
        property int popupRadius: 4
        function fontSize(scale) { return 10 * scale; }
    }
    QtObject {
        id: weather
        property var data: ({available: false, forecast: []})
        property bool refreshing: false
        property int calls: 0
        property bool forced: false
        function refresh(force) {
            calls++;
            forced = force;
            refreshing = true;
        }
    }
    Component { id: popupComponent; WeatherPopup { config: fixtureConfig; weatherData: weather } }

    TestCase {
        name: "WeatherPopup"
        when: windowShown
        property var popup: null
        property int closes: 0
        function init() {
            failOnWarning(/TypeError|Binding loop/);
            weather.refreshing = false;
            weather.calls = 0;
            closes = 0;
            popup = createTemporaryObject(popupComponent, host);
            verify(popup !== null);
            popup.closeRequested.connect(() => closes++);
            tryVerify(() => popup.activeFocus);
        }
        function test_f5_and_busy_feedback() {
            const hint = findChild(popup, "weatherRefreshHint");
            compare(hint.text, "F5 Refresh");
            keyClick(Qt.Key_F5);
            compare(weather.calls, 1);
            verify(weather.forced);
            compare(hint.text, "Refreshing…");
            keyClick(Qt.Key_F5);
            compare(weather.calls, 1);
            weather.refreshing = false;
            compare(hint.text, "F5 Refresh");
            keyClick(Qt.Key_F5);
            compare(weather.calls, 2);
        }
        function test_escape_and_other_modifiers() {
            keyClick(Qt.Key_F5, Qt.ControlModifier);
            compare(weather.calls, 0);
            keyClick(Qt.Key_Escape);
            compare(closes, 1);
        }
        function test_hint_is_not_a_refresh_button() {
            const hint = findChild(popup, "weatherRefreshHint");
            mouseClick(hint, hint.width / 2, hint.height / 2);
            compare(weather.calls, 0);
        }
    }
}
