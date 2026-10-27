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
    readonly property bool highlighted: selected || hover.hovered
    property string timeLabel: ""
    property string appIconSource: ""
    property var actionEntries: []

    signal picked()
    signal actionRequested(var entry)

    implicitHeight: Math.max(46, content.implicitHeight) + 20
    radius: config.popupRadius
    border.width: 1
    border.color: root.critical ? root.criticalBorderColor
        : root.highlighted ? root.config.selectionBackground : root.config.muted
    color: root.config.bg

    HoverHandler {
        id: hover
        objectName: "historyHoverHandler"
    }
    TapHandler { onTapped: root.picked() }

    Item {
        id: imageBox
        objectName: "historyIconBox"

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36

        Image {
            id: thumbnail
            objectName: "historyAppIcon"
            anchors.fill: parent
            source: root.critical ? "" : root.appIconSource
            sourceSize.width: Math.ceil(width * Screen.devicePixelRatio * 2)
            sourceSize.height: Math.ceil(height * Screen.devicePixelRatio * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !thumbnail.visible
            text: root.critical ? "󰀧" : "󰂚"
            color: root.critical ? root.criticalBorderColor
                : root.highlighted ? root.config.fg : root.config.muted
            font.family: root.config.iconFontFamily
            font.pointSize: root.config.iconSize
        }
    }

    Column {
        id: content
        x: 16
        y: 10
        width: Math.max(0, imageBox.x - x - 12)
        spacing: 4

        Item {
            width: parent.width
            height: Math.max(title.implicitHeight, timestamp.implicitHeight, 18)

            Text {
                id: title
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth,
                    Math.max(0, parent.width - timestamp.implicitWidth - 8))
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                text: root.notification ? root.notification.summary || "Notification" : ""
                color: root.critical ? root.criticalTextColor
                    : root.config.fg
                font.pointSize: root.config.fontSize(0.96)
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                id: timestamp
                anchors.left: title.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
                text: root.timeLabel
                color: root.critical ? root.criticalTextColor
                    : root.highlighted ? root.config.fg : root.config.muted
                font.pointSize: root.config.fontSize(0.72)
            }
        }

        Text {
            width: parent.width
            visible: text.length > 0
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: root.notification ? root.notification.body || "" : ""
            color: root.critical ? root.criticalTextColor
                : root.highlighted ? root.config.fg : root.config.muted
            font.pointSize: root.config.fontSize(0.85)
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
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
                    color: actionMouse.containsMouse
                        ? root.config.selectionBackground : root.config.bg
                    border.width: 1
                    border.color: root.config.selectionBackground
                    Text {
                        id: caption
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 16)
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        text: (actionButton.modelData.key ? "[" + actionButton.modelData.key + "] " : "") + actionButton.modelData.label
                        color: root.critical ? root.criticalTextColor
                            : actionMouse.containsMouse
                                ? root.config.selectionForeground : root.config.fg
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
