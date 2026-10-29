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
    readonly property int popupHeight: 520
    readonly property int popupPadding: 10

    signal closeRequested()

    implicitWidth: popupWidth
    implicitHeight: popupHeight
    width: implicitWidth
    height: implicitHeight
    focus: true
    Component.onCompleted: Qt.callLater(() => forceActiveFocus())
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const selectedCard = list.itemAtIndex(history.selectedIndex);
            if (selectedCard && selectedCard.expandableBody) {
                history.toggleExpanded(selectedCard.notification.id);
                event.accepted = true;
                return;
            }
        }
        if (history.handleKey(event.key, event.modifiers, event.text))
            event.accepted = true;
    }

    function keepSelectionVisible() {
        if (history.selectedIndex < 0 || history.selectedIndex >= list.count)
            return;

        const item = list.itemAtIndex(history.selectedIndex);
        if (!item) {
            list.positionViewAtIndex(history.selectedIndex, ListView.Contain);
            return;
        }

        const viewTop = list.contentY;
        const viewBottom = viewTop + list.height;
        if (item.height >= list.height)
            list.contentY = item.y;
        else if (item.y < viewTop)
            list.contentY = item.y;
        else if (item.y + item.height > viewBottom)
            list.contentY = item.y + item.height - list.height;
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
        border.color: root.config.border
        border.width: 1
        radius: root.config.popupRadius
    }

    // Scrollable history; selecting a card exposes its actions inline.
    ListView {
        id: list
        objectName: "historyList"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: historyFooter.top
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
            expanded: String(modelData.id) === history.expandedId
            critical: modelData.urgency === NotificationUrgency.Critical
            timeLabel: root.notificationService.timeLabel(modelData)
            appIconSource: root.historyIconSource(modelData)
            actionEntries: HistoryModel.actionsFor(modelData.actions)
            onHeightChanged: if (selected) Qt.callLater(root.keepSelectionVisible)
            onPicked: {
                history.select(index);
                root.forceActiveFocus();
            }
            onExpandRequested: history.toggleExpanded(modelData.id)
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

    // Persistent keyboard hints and the DND toggle.
        Item {
            id: historyFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.popupPadding
        height: Math.max(shortcutHint.implicitHeight, dndControls.implicitHeight) + 8

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.config.selectionBackground
        }

        Text {
            id: shortcutHint
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 10
            renderType: Text.NativeRendering
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.76)
            text: "x Dismiss · Ctrl+x Clear all"
        }

        Row {
            id: dndControls
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.notificationService.dnd
                renderType: Text.NativeRendering
                text: "DND"
                color: root.notificationService.dnd
                    ? root.config.selectionBackground : root.config.muted
                font.pointSize: root.config.fontSize(0.8)
            }

            ToggleSwitch {
                config: root.config
                checked: root.notificationService.dnd
                opacity: checked ? 1 : 0.8
                onToggled: {
                    root.notificationService.toggleDnd();
                    root.forceActiveFocus();
                }
            }
        }
    }
}
