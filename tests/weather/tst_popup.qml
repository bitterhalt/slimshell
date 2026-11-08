import QtQuick
import QtTest
import "../components"
import "../../weather"

Item {
    id: host
    width: 500
    height: 900
    ControlConfig {
        id: fixtureConfig
        fg: "white"
        muted: "gray"
        bg: "#151515"
        border: "#776655"
        selectionBackground: "#bb9955"
    }
    QtObject {
        id: weather
        property var data: ({
                available: false,
                forecast: []
            })
        property bool refreshing: false
        property int calls: 0
        function refresh(force) {
            calls++;
            refreshing = true;
        }
    }
    Component {
        id: popupComponent
        WeatherPopup {
            config: fixtureConfig
            weatherData: weather
        }
    }
    TestCase {
        name: "WeatherPopup"
        when: windowShown
        property var popup: null
        property int closes: 0
        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            fixtureConfig.fontSize = 10;
            fixtureConfig.iconSize = 10;
            weather.refreshing = false;
            weather.calls = 0;
            weather.data = {
                available: false,
                forecast: []
            };
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
        function test_icon_and_text_sizes_are_independent() {
            weather.data = {
                available: true,
                temperature: 12,
                moon: {
                    icon: "🌕",
                    name: "Full Moon",
                    illumination: 100
                },
                forecast: [
                    {
                        day: "Mon",
                        icon: "☀",
                        high: 12,
                        low: 5,
                        rain: 20
                    }
                ]
            };
            waitForPolish(host.Window.window);
            const main = findChild(popup, "weatherConditionIcon");
            const temperature = findChild(popup, "weatherTemperature");
            const detail = findChild(popup, "weatherDetailIcon");
            const moon = findChild(popup, "weatherMoonIcon");
            const forecast = findChild(popup, "weatherForecastIcon-0");
            fixtureConfig.iconSize = 12;
            fuzzyCompare(main.font.pointSize, 36, 0.01);
            fuzzyCompare(detail.font.pointSize, 12, 0.01);
            fuzzyCompare(moon.font.pointSize, 9.6, 0.01);
            fuzzyCompare(forecast.font.pointSize, 15.6, 0.01);
            fuzzyCompare(temperature.font.pointSize, 28, 0.01);
            fixtureConfig.fontSize = 12;
            fuzzyCompare(temperature.font.pointSize, 33.6, 0.01);
            fuzzyCompare(main.font.pointSize, 36, 0.01);
            compare(main.font.family, fixtureConfig.textFontFamily);
            compare(temperature.font.family, fixtureConfig.textFontFamily);
            compare(detail.font.family, fixtureConfig.iconFontFamily);
            popup.mainIconSize = 40;
            fuzzyCompare(main.font.pointSize, 40, 0.01);
            popup.mainTemperatureSize = 42;
            fuzzyCompare(temperature.font.pointSize, 42, 0.01);
            fuzzyCompare(detail.font.pointSize, 12, 0.01);
        }
        function test_complete_forecast_fits_surface() {
            weather.data = {
                available: true,
                place: "Example",
                icon: "☀",
                temperature: 12,
                condition: "Clear sky",
                feels: 10,
                humidity: 60,
                wind: 15,
                windDirection: "NW",
                visibility: 10,
                uv: 1,
                sunrise: "07:00",
                sunset: "17:00",
                moon: {
                    icon: "🌕",
                    name: "Full Moon",
                    illumination: 100
                },
                forecast: Array.from({
                    length: 7
                }, () => ({
                            day: "Mon",
                            icon: "☀",
                            high: 12,
                            low: 5,
                            rain: 20
                        }))
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
