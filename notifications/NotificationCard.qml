import "HistoryModel.js" as HistoryModel
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

Rectangle {
    id: root

    required property var config
    property var notification: null
    property bool compact: false
    property int bodyLineLimit: 3
    readonly property int appIconSize: 36
    readonly property string imageIcon: HistoryModel.iconFromImage(notification ? notification.image : "")
    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property bool timerNotification: notification && notification.appName === "QuickShell Timer"
    readonly property color criticalBorderColor: "#af3029"
    readonly property color criticalTextColor: "#ad8301"
    readonly property int actionCount: !compact && notification && notification.actions ? Math.min(notification.actions.length, 2) : 0

    function iconSource(icon) {
        if (!icon)
            return "";

        if (icon.startsWith("/") || icon.startsWith("file:"))
            return icon;

        return Quickshell.iconPath(icon, true);
    }

    implicitHeight: {
        let h = Math.max(compact ? 84 : 92, contentColumn.implicitHeight + 32);
        if (actionCount > 0)
            h += 34;

        return h;
    }
    radius: config.popupRadius
    color: config.bg
    border.color: critical ? criticalBorderColor : config.selectionBackground
    border.width: 1

    // App/icon hint on the right; text content stays in the left column.
    Item {
        id: imageBox

        objectName: "notificationIconBox"
        anchors.right: parent.right
        anchors.rightMargin: 22
        y: root.compact ? Math.round((parent.height - height) / 2) : 30
        width: root.appIconSize
        height: width

        IconImage {
            id: appIcon

            anchors.fill: parent
            visible: !root.critical && !root.timerNotification && source.toString() !== ""
            source: root.iconSource(root.notification ? (root.notification.appIcon || root.imageIcon) : "")
        }

        Text {
            anchors.centerIn: parent
            visible: root.critical || root.timerNotification || !appIcon.visible
            color: root.critical ? root.criticalTextColor : root.timerNotification ? config.selectionBackground : config.muted
            font.family: root.timerNotification ? config.textFontFamily : config.iconFontFamily
            font.pointSize: config.iconSize
            text: root.critical ? "󰀧" : root.timerNotification ? "⏰" : "󰂚"
        }

    }

    // Summary and body; bodyLineLimit controls how much message text is shown.
    Column {
        id: contentColumn

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: imageBox.left
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 2

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            color: root.critical ? root.criticalTextColor : config.fg
            font.pointSize: config.fontSize(0.96)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            text: root.notification ? (root.notification.summary || "") : ""
        }

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: text.length > 0
            color: root.critical ? root.criticalTextColor : config.muted
            font.pointSize: config.fontSize(0.86)
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: root.bodyLineLimit
            elide: Text.ElideRight
            text: root.notification ? (root.notification.body || "") : ""
        }

    }

    // Optional action buttons at the bottom of non-compact notifications.
    Row {
        id: actionsRow

        visible: root.actionCount > 0
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 6

        Repeater {
            model: root.actionCount

            Rectangle {
                required property int index

                width: (actionsRow.width - 6 * (root.actionCount - 1)) / root.actionCount
                height: 26
                radius: 3
                color: actionMouse.containsMouse ? config.selectionBackground : config.bg

                Text {
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: root.critical ? root.criticalTextColor : config.fg
                    font.pointSize: config.fontSize(0.8)
                    text: root.notification ? root.notification.actions[index].text : ""
                }

                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.notification)
                            root.notification.actions[index].invoke();

                    }
                }

            }

        }

    }

}
