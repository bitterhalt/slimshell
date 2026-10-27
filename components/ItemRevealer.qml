import QtQuick

Item {
    id: root

    required property var config
    required property var barWindow
    default property alias contentData: primaryRow.data
    property alias revealData: revealRow.data
    readonly property int revealDuration: 300
    property int hoverRevealDelay: 0
    property bool revealActive: false
    property real revealProgress: revealActive ? 1 : 0
    readonly property real revealExtent: revealRow.implicitWidth * revealProgress
    readonly property real revealSpacing: 8 * revealProgress

    implicitWidth: primaryRow.implicitWidth + revealSpacing + revealExtent
    height: barWindow.height

    HoverHandler {
        id: revealHover

        onHoveredChanged: {
            if (hovered) {
                if (root.hoverRevealDelay <= 0)
                    root.revealActive = true;
                else
                    revealTimer.restart();
            } else {
                revealTimer.stop();
                root.revealActive = false;
            }
        }
    }

    Timer {
        id: revealTimer

        interval: root.hoverRevealDelay
        onTriggered: {
            if (revealHover.hovered)
                root.revealActive = true;

        }
    }

    // Always-visible clock/workspace content.
    Row {
        id: primaryRow

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }

    // Clipped row revealed on hover; revealProgress also drives its spacing.
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
            spacing: 8
        }

    }

    Behavior on revealProgress {
        NumberAnimation {
            duration: root.revealDuration
            easing.type: Easing.OutCubic
        }

    }

}
