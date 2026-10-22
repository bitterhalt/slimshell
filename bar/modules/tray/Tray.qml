import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root

    required property var config
    required property var barWindow
    required property var popupManager

    height: barWindow.height
    implicitWidth: trayItems.implicitWidth

    Row {
        id: trayItems

        anchors.verticalCenter: parent.verticalCenter
        spacing: config.barModuleSpacing

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayItem

                required property var modelData

                width: 20
                height: barWindow.height

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: trayItem.modelData.icon
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate();
                            return ;
                        }
                        if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                            if (trayItem.modelData.hasMenu)
                                root.popupManager.toggleHost("trayMenu", trayMenuComponent, trayItem);

                            return ;
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
