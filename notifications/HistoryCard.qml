pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import "HistoryModel.js" as HistoryModel

Rectangle {
    id: root

    required property var config
    required property var notification
    property bool selected: false
    property bool critical: false
    readonly property color criticalTextColor: "#ad8301"
    readonly property color criticalBorderColor: "#af3029"
    property string timeLabel: ""
    property string appIconSource: ""
    property var actionEntries: []
    readonly property string previewSource: HistoryModel.previewImageSource(
        notification ? notification.image : "")
    readonly property bool hasImage: previewSource !== ""

    signal picked()
    signal closeRequested()
    signal actionRequested(var entry)

    implicitHeight: Math.max(46, content.implicitHeight) + 20
    radius: config.popupRadius
    border.width: 1
    border.color: root.critical ? root.criticalBorderColor
        : root.selected || hover.hovered ? root.config.accent : root.config.muted
    opacity: root.selected || hover.hovered ? 1 : 0.72
    color: root.selected ? Qt.alpha(root.config.accent, 0.12)
        : hover.hovered ? Qt.alpha(root.config.accent, 0.16)
        : Qt.alpha(root.config.bg, 0.3)

    HoverHandler {
        id: hover
        objectName: "historyHoverHandler"
    }
    TapHandler { onTapped: root.picked() }

    Image {
        id: thumbnail
        objectName: "historyAppIcon"
        x: 12
        y: 12
        width: 30
        height: 30
        source: root.critical ? "" : root.appIconSource
        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio * 2)
        sourceSize.height: Math.ceil(height * Screen.devicePixelRatio * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        visible: status === Image.Ready
    }

    Text {
        x: 12
        y: 14
        width: 30
        horizontalAlignment: Text.AlignHCenter
        visible: !thumbnail.visible
        text: root.critical ? "󰀧" : "󰂚"
        color: root.critical ? root.criticalBorderColor : root.config.muted
        font.family: root.config.iconFontFamily
        font.pointSize: root.config.iconSize
    }

    Column {
        id: content
        x: 50
        y: 10
        width: Math.max(0, root.width - x - 10)
        spacing: 4

        Item {
            width: parent.width
            height: Math.max(appName.implicitHeight, timestamp.implicitHeight, 18)

            Text {
                id: appName
                anchors.left: parent.left
                anchors.right: timestamp.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                text: root.notification ? root.notification.appName || "Notification" : ""
                color: root.critical ? root.criticalTextColor : root.selected ? root.config.fg : root.config.muted
                font.pointSize: root.config.fontSize(0.78)
                elide: Text.ElideRight
            }
            Text {
                id: timestamp
                anchors.right: closeButton.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
                text: root.timeLabel
                color: root.critical ? root.criticalTextColor : root.selected ? root.config.fg : root.config.muted
                font.pointSize: root.config.fontSize(0.72)
            }
            Item {
                id: closeButton
                objectName: "historyCloseButton"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: root.critical ? root.criticalTextColor
                        : root.selected || closeMouse.containsMouse ? root.config.fg : root.config.muted
                    font.pointSize: root.config.fontSize(1)
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Text {
            width: parent.width
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: root.notification ? root.notification.summary || "" : ""
            color: root.critical ? root.criticalTextColor : root.config.fg
            font.pointSize: root.config.fontSize(0.96)
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text.length > 0
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: root.notification ? root.notification.body || "" : ""
            color: root.critical ? root.criticalTextColor : root.config.muted
            font.pointSize: root.config.fontSize(0.85)
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Image {
            id: preview
            objectName: "historyImagePreview"
            readonly property real aspectRatio: implicitWidth > 0 && implicitHeight > 0
                ? implicitWidth / implicitHeight : 1
            width: root.selected && root.hasImage ? Math.min(content.width, 240, 120 * aspectRatio) : 0
            height: width > 0 ? width / aspectRatio : 0
            visible: root.selected && root.hasImage && status === Image.Ready
            source: root.selected && root.hasImage ? root.previewSource : ""
            sourceSize.width: Math.ceil(Math.min(content.width, 240) * Screen.devicePixelRatio * 2)
            sourceSize.height: Math.ceil(120 * Screen.devicePixelRatio * 2)
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            smooth: true
            asynchronous: true
        }

        Flow {
            id: actions
            width: parent.width
            spacing: 6
            visible: root.selected
            Repeater {
                model: root.selected ? root.actionEntries : []
                delegate: Rectangle {
                    id: actionButton
                    required property var modelData
                    objectName: "historyAction-" + modelData.key
                    width: Math.min(actions.width, caption.implicitWidth + 16)
                    height: 26
                    radius: 3
                    color: actionMouse.containsMouse ? root.config.accent : root.config.bg
                    border.width: 1
                    border.color: root.config.accent
                    Text {
                        id: caption
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 16)
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        text: (actionButton.modelData.key ? "[" + actionButton.modelData.key + "] " : "") + actionButton.modelData.label
                        color: root.critical ? root.criticalTextColor : root.config.fg
                        font.pointSize: root.config.fontSize(0.78)
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.actionRequested(actionButton.modelData)
                    }
                }
            }
        }
    }
}
