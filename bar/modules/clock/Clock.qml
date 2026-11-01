import QtQuick
import Quickshell

import "../../../components"
import "../../../weather"

ItemRevealer {
  id: root

  required property var popupManager
  required property var weatherData
  required property var uiService

  function weatherAction(action): void {
    if (action === "close" || root.barWindow.screen !== root.uiService.targetScreen) {
      root.popupManager.closeHost("weather")
      return
    }
    if (action === "toggle")
      root.popupManager.toggleHost("weather", weatherPopupComponent, root, true, true)
    else if (action === "open")
      root.popupManager.openHost("weather", weatherPopupComponent, root, true, true)
  }

  Component {
    id: weatherPopupComponent
    WeatherPopup {
      config: root.config
      weatherData: root.weatherData
      onCloseRequested: root.popupManager.closeHost("weather")
    }
  }

  Connections {
    target: root.uiService
    function onWeatherActionRequested(action): void { root.weatherAction(action) }
  }

  // Primary bar time; the alternative date format is revealed on hover.
  Text {
    renderType: Text.NativeRendering
    color: root.config.fg
    font.pointSize: root.config.fontSize(1)
    font.weight: Font.DemiBold
    text: Qt.formatDateTime(clock.date, root.config.clockFormat)

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }
  }

  revealData: [
    Text {
      renderType: Text.NativeRendering
      color: root.config.fg
      font.pointSize: root.config.fontSize(1)
      font.weight: Font.DemiBold
      textFormat: Text.RichText

      text: {
        const formatted = Qt.formatDateTime(
          clock.date,
          root.config.clockAlternativeFormat
        )
        const weekday = Qt.formatDateTime(clock.date, "dddd")

        return formatted.replace(
          weekday,
          "<span style='color:" + root.config.selectionBackground + "'>"
            + weekday
            + "</span>"
        )
      }
    },
    Text {
      renderType: Text.NativeRendering
      color: root.config.fg
      font.pointSize: root.config.fontSize(1)
      font.weight: Font.DemiBold
      text: root.weatherData.data.available
        ? root.weatherData.data.temperature + "°C" : "N/A"
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popupManager.toggleHost("weather", weatherPopupComponent, root, true, true)
      }
    }
  ]
}
