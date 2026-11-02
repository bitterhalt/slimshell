import QtQuick
import QtTest
import "../../weather"

Item {
    id: host
    width: 500
    height: 900
    QtObject {
        id: fixtureConfig
        property color fg: "white"
        property color muted: "gray"
        property color bg: "#151515"
        property color border: "#776655"
        property color selectionBackground: "#bb9955"
        property string iconFontFamily: "sans-serif"
        property int popupRadius: 4
        function fontSize(scale) { return 10 * scale; }
    }
    QtObject {
        id: weather
        property var data: ({available: false, forecast: []})
        property bool refreshing: false
        property int calls: 0
        function refresh(force) { calls++; refreshing = true; }
    }
    Component { id: popupComponent; WeatherPopup { config: fixtureConfig; weatherData: weather } }
    TestCase {
        name: "WeatherPopup"
        when: windowShown
        property var popup: null
        property int closes: 0
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            weather.refreshing = false;
            weather.calls = 0;
            weather.data = {available: false, forecast: []};
            closes = 0;
            popup = createTemporaryObject(popupComponent, host);
            verify(popup !== null);
            popup.closeRequested.connect(() => closes++);
            tryVerify(() => popup.activeFocus);
        }
        function test_refresh_and_busy_feedback() {
            const hint = findChild(popup, "weatherRefreshHint");
            compare(hint.text, "F5 Refresh");
            keyClick(Qt.Key_F5);
            compare(weather.calls, 1);
            compare(hint.text, "Refreshing…");
            keyClick(Qt.Key_F5);
            compare(weather.calls, 1);
        }
        function test_escape_and_modifiers() {
            keyClick(Qt.Key_F5, Qt.ControlModifier);
            compare(weather.calls, 0);
            keyClick(Qt.Key_Escape);
            compare(closes, 1);
        }
        function test_refresh_hint_is_not_a_button() {
            const hint = findChild(popup, "weatherRefreshHint");
            mouseClick(hint, hint.width / 2, hint.height / 2);
            compare(weather.calls, 0);
        }
        function test_complete_forecast_fits_surface() {
            weather.data = {
                available: true, place: "Example", icon: "☀", temperature: 12,
                condition: "Clear sky", feels: 10, humidity: 60, wind: 15,
                windDirection: "NW", visibility: 10, uv: 1, sunrise: "07:00", sunset: "17:00",
                moon: {icon: "🌕", name: "Full Moon", illumination: 100},
                forecast: Array.from({length: 7}, () => ({day: "Mon", icon: "☀", high: 12, low: 5, rain: 20}))
            };
            wait(50);
            verify(popup.height > 300);
            verify(popup.height < host.height);
            const firstRow = findChild(popup, "weatherForecast-0");
            const lastRow = findChild(popup, "weatherForecast-6");
            verify(firstRow !== null);
            verify(lastRow !== null);
            compare(firstRow.width, popup.width - 32);
            verify(lastRow.mapToItem(popup, 0, lastRow.height).y <= popup.height);
        }
    }
}
