import "../components"
import "../notifications"
import "../recorder"
import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/audio"
import "modules/battery"
import "modules/bluetooth"
import "modules/clock"
import "modules/idle"
import "modules/network"
import "modules/tray"
import "modules/window"
import "modules/workspaces"

PanelWindow {
    id: barWindow

    required property var targetScreen
    required property var config
    required property var niri
    required property var notificationService
    required property var notificationPopup
    required property var bluetoothService
    required property var audioService
    required property var networkService
    required property var batteryService
    required property var idleService
    required property var settingsService
    required property var recorderService
    required property var uiService

    screen: targetScreen
    implicitHeight: config.barHeight
    color: config.bg
    WlrLayershell.namespace: "slim-bar"

    anchors {
        top: true
        left: true
        right: true
    }

    PopupManager {
        id: popupManager

        barWindow: barWindow
        config: barWindow.config
    }

    // ---------------------------------------------------------
    // LEFT
    // Change module order here.
    // ---------------------------------------------------------
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Workspaces {
            config: barWindow.config
            barWindow: barWindow
            niri: barWindow.niri
            settingsService: barWindow.settingsService
        }

        WindowTitle {
            config: barWindow.config
            barWindow: barWindow
            niri: barWindow.niri
        }

    }

    // ---------------------------------------------------------
    // CENTER
    // Change module order here.
    // ---------------------------------------------------------
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Clock {
            config: barWindow.config
            barWindow: barWindow
        }

        NotificationIndicator {
            config: barWindow.config
            barWindow: barWindow
            popupManager: popupManager
            notificationService: barWindow.notificationService
            notificationPopup: barWindow.notificationPopup
            uiService: barWindow.uiService
        }

        Recorder {
            config: barWindow.config
            barWindow: barWindow
            recorderService: barWindow.recorderService
        }

    }

    // ---------------------------------------------------------
    // RIGHT
    // Change module order here.
    // ---------------------------------------------------------
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Network {
            config: barWindow.config
            barWindow: barWindow
            popupManager: popupManager
            uiService: barWindow.uiService
            networkService: barWindow.networkService
        }

        Bluetooth {
            config: barWindow.config
            barWindow: barWindow
            popupManager: popupManager
            bluetoothService: barWindow.bluetoothService
            uiService: barWindow.uiService
        }

        Audio {
            config: barWindow.config
            barWindow: barWindow
            popupManager: popupManager
            uiService: barWindow.uiService
            audioService: barWindow.audioService
        }

        Idle {
            config: barWindow.config
            barWindow: barWindow
            idleService: barWindow.idleService
        }

        Battery {
            config: barWindow.config
            barWindow: barWindow
            battery: barWindow.batteryService
        }

        Tray {
            visible: barWindow.config.showTray
            config: barWindow.config
            barWindow: barWindow
            popupManager: popupManager
        }

    }

}
