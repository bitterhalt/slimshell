import QtQuick

Item {
    id: root

    required property var config
    required property var barWindow

    default property alias contentData: primaryRow.data
    property alias revealData: revealRow.data

    readonly property int revealDuration: 300
    property real revealProgress: revealHover.hovered ? 1 : 0
    readonly property real revealExtent: revealRow.implicitWidth * revealProgress
    readonly property real revealSpacing: config.barModuleSpacing * revealProgress

    implicitWidth: primaryRow.implicitWidth + revealSpacing + revealExtent
    height: barWindow.height

    Behavior on revealProgress {
        NumberAnimation {
            duration: root.revealDuration
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: revealHover
    }

    Row {
        id: primaryRow

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.config.barModuleSpacing
    }

    Item {
        id: revealClip

        x: primaryRow.implicitWidth + root.revealSpacing
        anchors.verticalCenter: parent.verticalCenter
        width: root.revealExtent
        height: revealRow.implicitHeight
        clip: true

        Row {
            id: revealRow

            x: revealClip.width - implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.config.barModuleSpacing
        }
    }
}
