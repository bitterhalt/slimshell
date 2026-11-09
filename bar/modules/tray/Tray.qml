import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root

    required property var config
    required property var barWindow
    required property var popupManager
    property bool expanded: false

    readonly property real revealProgress: expanded ? 1 : 0
    readonly property real revealWidth: trayItems.implicitWidth > 0 ? trayItems.implicitWidth + 8 : 0

    height: barWindow.height
    implicitWidth: toggleButton.width + revealWidth * revealProgress

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

                x: revealClip.width - implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: trayItem
                        required property var modelData

                        width: 20
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

            width: 24
            height: root.height

            Text {
                id: toggleIcon

                anchors.centerIn: parent
                color: toggleMouse.containsMouse ? root.config.selectionBackground : root.config.muted
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

            MouseArea {
                id: toggleMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
