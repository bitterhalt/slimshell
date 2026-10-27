import QtQuick
import Quickshell

import "../../../components"

ItemRevealer {
  id: root

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
    }
  ]
}
