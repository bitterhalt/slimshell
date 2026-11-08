import "../components/CriticalColors.js" as CriticalColors
import "HistoryModel.js" as HistoryModel
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// Toast preview only. Full text and actions belong to notification history.
Rectangle {
    id: root

    required property var config
    property var notification: null
    readonly property int appIconSize: 36
    readonly property string imageIcon: HistoryModel.iconFromImage(notification ? notification.image : "")
    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property color criticalBorderColor: CriticalColors.border
    readonly property color criticalTextColor: CriticalColors.text

    implicitHeight: 100
    clip: true
    radius: config.popupRadius
    color: config.bg
    border.color: critical ? criticalBorderColor : config.border
    border.width: 1

    Item {
        id: imageBox

        objectName: "notificationIconBox"
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: root.appIconSize
        height: width

        IconImage {
            id: appIcon

            anchors.fill: parent
            visible: !root.critical && source.toString() !== ""
            source: HistoryModel.iconSource(root.notification ? (root.notification.appIcon || root.imageIcon) : "", (name, fallback) => Quickshell.iconPath(name, fallback))
        }

        Text {
            anchors.centerIn: parent
            visible: root.critical || !appIcon.visible
            color: root.critical ? root.criticalTextColor : config.muted
            font.family: config.iconFontFamily
            font.pointSize: config.iconSize
            text: root.critical ? "󰀧" : "󰂚"
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: imageBox.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            textFormat: Text.PlainText
            color: root.critical ? root.criticalTextColor : config.fg
            font.pointSize: config.textSizeNormal
            font.weight: Font.DemiBold
            maximumLineCount: 1
            elide: Text.ElideRight
            text: root.notification ? (root.notification.summary || "") : ""
        }

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: text.length > 0
            color: root.critical ? root.criticalTextColor : config.muted
            font.pointSize: config.textSizeMedium
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.notification ? (root.notification.body || "") : ""
        }
    }
}
