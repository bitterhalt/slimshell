pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../components"
import "HistoryModel.js" as HistoryModel

FocusScope {
    id: root

    required property var config
    required property var notificationService
    readonly property int popupWidth: 360
    readonly property int popupMinHeight: 320
    readonly property int popupMaxHeight: 650
    readonly property int popupPadding: 10

    signal closeRequested()

    implicitWidth: popupWidth
    implicitHeight: Math.min(Math.max(notificationService.notificationCount > 0
        ? 44 + notificationService.notificationCount * 100 : 82, popupMinHeight), popupMaxHeight)
    width: implicitWidth
    height: implicitHeight
    focus: true
    Component.onCompleted: Qt.callLater(() => forceActiveFocus())
    Keys.onPressed: event => {
        if (history.handleKey(event.key, event.modifiers, event.text))
            event.accepted = true;
    }

    function keepSelectionVisible() {
        if (history.selectedIndex >= 0 && history.selectedIndex < list.count)
            list.positionViewAtIndex(history.selectedIndex, ListView.Contain);
    }

    function iconSource(icon) {
        if (!icon)
            return "";
        return icon.startsWith("/") || icon.startsWith("file:")
            ? icon : Quickshell.iconPath(icon, true);
    }

    function historyIconSource(notification) {
        const appIcon = notification ? notification.appIcon || "" : "";
        if (appIcon)
            return iconSource(appIcon);

        const icon = HistoryModel.iconFromImage(notification ? notification.image : "");
        if (!icon)
            return "";
        return icon.startsWith("/") ? icon : iconSource(icon);
    }

    HistoryState {
        id: history
        objectName: "historyState"
        notificationService: root.notificationService
        onSelectionMoved: Qt.callLater(root.keepSelectionVisible)
        onCloseRequested: root.closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        color: root.config.bg
        border.color: root.config.selectionBackground
        border.width: 1
        radius: root.config.popupRadius
    }

    ListView {
        id: list
        objectName: "historyList"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: history.helpOpen ? helpText.top : historyFooter.top
        anchors.leftMargin: root.popupPadding
        anchors.rightMargin: root.popupPadding
        anchors.topMargin: root.popupPadding
        anchors.bottomMargin: 8
        visible: count > 0
        clip: true
        spacing: 4
        keyNavigationEnabled: false
        onCountChanged: Qt.callLater(root.keepSelectionVisible)

        // Preserve delegates when notifications arrive or disappear.
        model: ScriptModel { values: history.rows }

        delegate: HistoryCard {
            id: card
            required property var modelData
            required property int index

            width: list.width
            config: root.config
            notification: modelData
            selected: index === history.selectedIndex
            critical: modelData.urgency === NotificationUrgency.Critical
            timeLabel: root.notificationService.timeLabel(modelData)
            appIconSource: root.historyIconSource(modelData)
            actionEntries: HistoryModel.actionsFor(modelData.actions)
            onHeightChanged: if (selected) Qt.callLater(root.keepSelectionVisible)
            onPicked: {
                history.select(index);
                root.forceActiveFocus();
            }
            onCloseRequested: {
                history.select(index);
                history.dismissSelected();
                root.forceActiveFocus();
            }
            onActionRequested: entry => {
                history.select(index);
                history.invoke(entry);
                root.forceActiveFocus();
            }
        }
    }

    Text {
        anchors.centerIn: list
        visible: history.rows.length === 0
        renderType: Text.NativeRendering
        text: "No notifications"
        color: root.config.muted
        font.pointSize: root.config.fontSize(0.9)
    }

    Text {
        id: helpText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: historyFooter.top
        anchors.margins: root.popupPadding
        visible: history.helpOpen
        renderType: Text.NativeRendering
        wrapMode: Text.WordWrap
        color: root.config.muted
        font.pointSize: root.config.fontSize(0.78)
        text: "↑/↓ or j/k Select · Tab Next · Enter Default action · x Close · Ctrl+C Clear all · Lettered buttons invoke actions · Esc Back/Close"
    }

    Item {
        id: historyFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.popupPadding
        height: Math.max(helpHint.implicitHeight, dndControls.implicitHeight) + 8

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.config.selectionBackground
        }

        Text {
            id: helpHint
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 8
            renderType: Text.NativeRendering
            color: helpMouse.containsMouse ? root.config.fg : root.config.muted
            font.pointSize: root.config.fontSize(0.76)
            text: history.helpOpen ? "Esc Back" : "? Help"
            MouseArea {
                id: helpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    history.helpOpen = !history.helpOpen;
                    root.forceActiveFocus();
                }
            }
        }

        Row {
            id: dndControls
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
                text: "DND"
                color: root.notificationService.dnd
                    ? root.config.selectionBackground : root.config.muted
                font.pointSize: root.config.fontSize(0.8)
            }

            ToggleSwitch {
                config: root.config
                checked: root.notificationService.dnd
                onToggled: {
                    root.notificationService.toggleDnd();
                    root.forceActiveFocus();
                }
            }
        }
    }
}
