import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var config
    required property var targetScreen
    readonly property int cardPadding: 14

    screen: targetScreen
    color: "transparent"
    implicitWidth: labels.width + cardPadding * 2
    implicitHeight: labels.implicitHeight + cardPadding * 2
    exclusiveZone: 0
    focusable: false
    margins.top: config.zenCardMargin
    margins.right: config.zenCardMargin
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "slim-zen-card"
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

    Rectangle {
        anchors.fill: parent
        color: root.config.bg
        opacity: root.config.zenCardOpacity
        radius: root.config.popupRadius
    }

    Column {
        id: labels

        x: root.cardPadding
        y: root.cardPadding
        width: Math.max(timeText.implicitWidth, modeText.implicitWidth)
        spacing: 4

        Text {
            id: modeText

            width: labels.width
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: "Zen Mode"
            color: root.config.muted
            font.family: root.config.textFontFamily
            font.pointSize: root.config.fontSize(0.96)
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: timeText

            width: labels.width
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: Qt.formatDateTime(clock.date, root.config.clockFormat)
            color: root.config.muted
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
