import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root

    required property var config
    required property var barWindow
    required property var popupManager
    property bool expanded: false
    readonly property int hoverRevealDelay: 300
    readonly property int trayItemWidth: 20
    readonly property bool hasItems: trayItems.implicitWidth > 0
    readonly property bool trayMenuOpen: popupManager.hostRequested && popupManager.activeKey === "trayMenu"

    property real revealProgress: 0
    readonly property real revealWidth: trayItems.implicitWidth > 0 ? trayItems.implicitWidth + config.spacingControl : 0

    height: barWindow.height
    width: implicitWidth
    implicitWidth: (hasItems ? toggleButton.width : 0) + revealWidth * revealProgress
    onExpandedChanged: revealProgress = expanded ? 1 : 0

    HoverHandler {
        id: revealHover

        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered)
                revealTimer.restart();
            else {
                revealTimer.stop();
                if (!root.trayMenuOpen)
                    root.expanded = false;
            }
        }
    }

    Timer {
        id: revealTimer
        interval: root.hoverRevealDelay
        onTriggered: {
            if (revealHover.hovered)
                root.expanded = true;
        }
    }

    Connections {
        target: root.popupManager

        function onHostRequestedChanged() {
            if (!root.trayMenuOpen && !revealHover.hovered)
                root.expanded = false;
        }

        function onActiveKeyChanged() {
            if (!root.trayMenuOpen && !revealHover.hovered)
                root.expanded = false;
        }
    }

    Behavior on revealProgress {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    // Tray is at the right edge of the bar, so items reveal to the icon's left.
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Item {
            id: revealClip

            width: root.revealWidth * root.revealProgress
            height: root.height
            clip: true

            Row {
                id: trayItems

                x: revealClip.width - implicitWidth - root.config.spacingControl
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.config.spacingControl

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: trayItem
                        required property var modelData

                        width: root.trayItemWidth
                        height: root.barWindow.height

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 16
                            source: trayItem.modelData.icon
                        }

                        // Left-click activates; right-click opens the item's menu.
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton) {
                                    trayItem.modelData.secondaryActivate();
                                    return;
                                }
                                if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                    if (trayItem.modelData.hasMenu)
                                        root.popupManager.toggleHost("trayMenu", trayMenuComponent, trayItem);

                                    return;
                                }
                                trayItem.modelData.activate();
                            }
                        }

                        Component {
                            id: trayMenuComponent

                            TrayMenu {
                                config: root.config
                                menuHandle: trayItem.modelData.menu
                                popupManager: root.popupManager
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: toggleButton

            width: root.hasItems ? root.trayItemWidth : 0
            height: root.height

            Text {
                id: toggleIcon

                anchors.centerIn: parent
                color: revealHover.hovered ? root.config.selectionBackground : root.config.muted
                font.family: root.config.iconFontFamily
                font.pointSize: root.config.iconSize
                text: "󰅀"
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
