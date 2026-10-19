import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var config
    required property var targetScreen

    screen: targetScreen
    color: "transparent"
    implicitWidth: labels.width
    implicitHeight: labels.implicitHeight
    exclusiveZone: 0
    focusable: false
    margins.top: config.zenWatermarkMargin
    margins.right: config.zenWatermarkMargin
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "slim-zen-watermark"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }

    SystemClock {
        id: clock

        enabled: root.visible
        precision: SystemClock.Minutes
    }

    Column {
        id: labels

        width: Math.max(timeText.implicitWidth, modeText.implicitWidth)
        spacing: 4
        opacity: root.config.zenWatermarkOpacity

        Text {
            id: modeText

            width: labels.width
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: "Zen mode"
            color: root.config.fg
            font.family: root.config.textFontFamily
            font.pointSize: root.config.fontSize(1)
            horizontalAlignment: Text.AlignRight
        }

        Text {
            id: timeText

            width: labels.width
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: Qt.formatDateTime(clock.date, root.config.clockFormat)
            color: root.config.fg
            font.family: root.config.textFontFamily
            font.pointSize: root.config.fontSize(2.8)
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
        }

    }

    // An empty input region lets all pointer events reach the desktop below.
    mask: Region {
    }

}
