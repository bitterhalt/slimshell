import QtQuick
import Quickshell
import Quickshell.Wayland

import "../components"

Item {
    id: root

    required property var config
    required property var barWindow
    required property var recorderService

    readonly property bool runningNow: recorderService.runningNow
    readonly property bool ipcOwner:
        barWindow.screen === recorderService.targetScreen

    property int selectedIndex: 0
    property bool opened: false
    readonly property int actionCount: runningNow ? 3 : 2

    width: runningNow ? 24 : 0
    height: barWindow.height
    visible: runningNow

    function open(): void {
        selectedIndex = 0
        menuCard.prepareLayout()
        opened = true
        Qt.callLater(() => keyboardHandler.forceActiveFocus())
    }

    function close(): void {
        opened = false
    }

    function toggle(): void {
        opened ? close() : open()
    }

    function selectNext(): void {
        selectedIndex = (selectedIndex + 1) % actionCount
    }

    function selectPrevious(): void {
        selectedIndex =
            (selectedIndex - 1 + actionCount) % actionCount
    }

    function activateSelected(): void {
        switch (selectedIndex) {
        case 0:
            fullscreen()
            break
        case 1:
            region()
            break
        case 2:
            stop()
            break
        }
    }

    function fullscreen(): void {
        close()
        recorderService.fullscreen()
    }

    function region(): void {
        close()

        if (recorderService.canStart())
            regionSelector.open()
    }

    function stop(): void {
        close()
        recorderService.stop()
    }

    Text {
        renderType: Text.NativeRendering
        id: recordingLabel

        anchors.centerIn: parent
        color: config.selectionBackground
        font.pointSize: config.fontSize(1)
        font.weight: Font.DemiBold
        text: "REC"

        SequentialAnimation on opacity {
            running: root.runningNow && root.visible
            loops: Animation.Infinite
            onRunningChanged: if (!running) recordingLabel.opacity = 1

            PauseAnimation { duration: 500 }
            NumberAnimation { from: 1; to: 0; duration: 100 }
            PauseAnimation { duration: 400 }
            PropertyAction { value: 1 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

    // Full-screen drag selector used by the Region menu action.
    RegionSelector {
        id: regionSelector

        config: root.config
        targetScreen: root.barWindow.screen

        onAccepted: geometry => {
            root.recorderService.startRegion(geometry)
        }
    }

    // Keyboard-driven recorder action menu.
    PanelWindow {
        id: recorderMenu

        screen: root.barWindow.screen

        anchors {
            top: true
            left: true
        }

        implicitWidth: menuCard.implicitWidth
        implicitHeight: menuCard.implicitHeight
        margins.top: root.config.popupGap
        margins.left: root.barWindow.screen
            ? Math.max(0, Math.round((root.barWindow.screen.width - menuCard.implicitWidth) / 2)) : 0

        visible: popupMotion.surfaceVisible
        color: "transparent"
        exclusiveZone: 0
        focusable: root.opened

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "slim-submenu"
        WlrLayershell.keyboardFocus: root.opened
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        FocusScope {
            id: keyboardHandler

            anchors.fill: parent
            focus: true
            enabled: root.opened

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Up:
                case Qt.Key_Backtab:
                    root.selectPrevious()
                    event.accepted = true
                    return

                case Qt.Key_Down:
                case Qt.Key_Tab:
                    root.selectNext()
                    event.accepted = true
                    return

                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.activateSelected()
                    event.accepted = true
                    return

                case Qt.Key_Escape:
                    root.close()
                    event.accepted = true
                    return
                }

                switch (event.text.toLowerCase()) {
                case "f":
                    root.fullscreen()
                    event.accepted = true
                    break

                case "r":
                    root.region()
                    event.accepted = true
                    break

                case "s":
                    if (root.runningNow)
                        root.stop()
                    event.accepted = true
                    break
                }
            }
        }

        PopoutPanel {
            id: menuCard

            enabled: root.opened
            opacity: popupMotion.contentOpacity
            transform: Translate { y: popupMotion.contentOffset }
            z: 1
            config: root.config
            contentWidth: 190
            padding: 12
            spacing: 4

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            // Fullscreen, region, and stop actions.
            RecorderMenuItem {
                index: 0
                icon: "󰑋"
                label: "Fullscreen"
                keyHint: "f"
            }

            RecorderMenuItem {
                index: 1
                icon: "󰩬"
                label: "Region"
                keyHint: "r"
            }

            RecorderMenuItem {
                index: 2
                icon: "󰙦"
                label: "Stop"
                keyHint: "s"
                visible: root.runningNow
                height: root.runningNow ? 32 : 0
            }
        }

    }

    PopupMotion {
        id: popupMotion
        shown: root.opened
        animationsEnabled: root.config.popupAnimations
        animationType: root.config.popupAnimationStyle
        duration: root.config.popupDuration
        surfaceHeight: recorderMenu.height
    }

    PopupCatcher {
        targetScreen: root.barWindow.screen
        visible: popupMotion.surfaceVisible
        onDismissed: root.close()
    }

    component RecorderMenuItem: Item {
        id: menuItem

        required property int index
        required property string icon
        required property string label
        required property string keyHint

        readonly property bool selected:
            root.selectedIndex === menuItem.index

        width: parent ? parent.width : 0
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: menuItem.selected
                ? root.config.selectionBackground
                : "transparent"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter

            width: 22
            color: menuItem.selected
                ? root.config.selectionForeground : root.config.fg
            font.family: root.config.iconFontFamily
            font.pointSize: root.config.iconSize * 1.077
            horizontalAlignment: Text.AlignHCenter
            text: menuItem.icon
        }

        Text {
            renderType: Text.NativeRendering
            anchors.left: parent.left
            anchors.leftMargin: 38
            anchors.verticalCenter: parent.verticalCenter

            color: menuItem.selected
                ? root.config.selectionForeground : root.config.fg
            font.pointSize: root.config.fontSize(1)
            font.weight: Font.Medium
            text: menuItem.label
        }

        Text {
            renderType: Text.NativeRendering
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            width: 21
            horizontalAlignment: Text.AlignHCenter
            color: menuItem.selected
                ? root.config.selectionForeground : root.config.fg
            font.pointSize: root.config.fontSize(0.846)
            font.weight: Font.Normal
            text: menuItem.keyHint
        }

    }

    Connections {
        target: recorderService

        function onMenuActionRequested(action): void {
            if (action === "close") {
                root.close()
                return
            }

            if (!root.ipcOwner) {
                root.close()
                return
            }

            if (action === "toggle")
                root.toggle()
            else if (action === "open")
                root.open()
        }

        function onRegionSelectionRequested(): void {
            if (root.ipcOwner)
                root.region()
        }
    }
}
