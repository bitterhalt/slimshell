import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../components"

Item {
    id: root

    required property var config
    required property var targetScreen
    required property var lockService
    required property var idleService
    required property var wallpaperPicker

    property string page: ""
    property bool opened: false
    property int selectedIndex: 0
    property var menuScreen: null
    property var confirmItem: null
    property int confirmIndex: -1

    // Page contents and keyboard shortcuts. Edit labels/actions here.
    readonly property var powerItems: [
        { label: "Lock", icon: "󰌾", shortcut: "l", action: "lock" },
        { label: "Log out", icon: "󰍃", shortcut: "e", command: "niri msg action quit", confirm: true },
        { label: "Sleep", icon: "󰤄", shortcut: "z", action: "suspend" },
        { label: "Restart", icon: "󰜉", shortcut: "r", command: "systemctl reboot", confirm: true },
        { label: "Shut down", icon: "󰐥", shortcut: "s", command: "systemctl poweroff", confirm: true }
    ]


    readonly property var packagesItems: [
        { label: "Install Packages", icon: "󰏗", shortcut: "i", command: "foot -a pacseek -T pacseek -e pacseek -m" },
        { label: "Update", icon: "󰑐", shortcut: "u", command: "foot -a pop-upgrade -e sup" }
    ]


    readonly property var settingsItems: [
        { label: "Niri", icon: "󰖲", shortcut: "n", command: "foot sh -c 'cd ~/.config/niri/ && nvim *'" },
        { label: "Nvim", icon: "", shortcut: "v", command: "foot sh -c 'cd ~/.config/nvim && vopen .'" },
        { label: "Hellwal", icon: "󰏘", shortcut: "p", command: "foot -e nvim  ~/.config/hellwal/templates/*" },
        { label: "Quickshell", icon: "󰆍", shortcut: "q", command: "foot sh -c 'cd ~/.config/quickshell && vopen .'" },
    ]

    readonly property var systemItems: [
        { label: "Network Manager", icon: "󰲝", shortcut: "n", command: "foot -e nmtui" },
        { label: "Update System", icon: "󰑐", shortcut: "u", command: "foot -a pop-upgrade -e sup" },
        { label: "Idle Settings", icon: "󰤄", shortcut: "i", action: "idleSettings" },
        { label: "Monitor", icon: "󰨇", shortcut: "m", page: "monitor" },
    ]

    readonly property var monitorItems: [
        { label: "Atop [AMD GPU Monitor]", icon: "󰾲", shortcut: "a", command: "foot -T atop -e amdgpu_top --smi" },
        { label: "Btop [System Monitor]", icon: "󰨇", shortcut: "b", command: "foot -a btop -e btop" },
        { label: "Nethogs [Network Monitor]", icon: "󰛳", shortcut: "n", command: "foot -a nethogs -e nethogs" },
        { label: "Logs", icon: "󰌱", shortcut: "l", command: "foot -a foot -T journalctl -e journalctl -f" },
        { label: "Combined", icon: "󰕮", shortcut: "c", command: "foot -a Sysmon -T Sysmon -e ~/.local/bin/tmux-sysmon.sh" }
    ]

    readonly property var currentItems: {
        if (confirmItem)
            return [
                { label: "Yes", icon: "󰄬", shortcut: "y" },
                { label: "No", icon: "󰅖", shortcut: "n" }
            ]

        switch (page) {
        case "power":
            return powerItems
        case "packages":
            return packagesItems
        case "settings":
            return settingsItems
        case "system":
            return systemItems
        case "monitor":
            return monitorItems
        default:
            return []
        }
    }

    readonly property string title: {
        switch (page) {
        case "power":
            return "Power"
        case "packages":
            return "Packages"
        case "settings":
            return "Edit configs"
        case "system":
            return "Settings"
        case "monitor":
            return "Monitor"
        default:
            return ""
        }
    }

    function open(name, screen): void {
        cancelConfirmation()
        page = name || "power"
        menuScreen = screen || targetScreen
        selectedIndex = 0
        menuCard.prepareLayout()
        opened = true
        Qt.callLater(() => keyboardHandler.forceActiveFocus())
    }

    function close(): void {
        cancelConfirmation()
        opened = false
    }

    function toggle(name, screen): void {
        const requestedPage = name || "power"
        if (opened && page === requestedPage)
            close()
        else
            open(requestedPage, screen)
    }

    function cancelConfirmation(): void {
        if (!confirmItem)
            return

        selectedIndex = confirmIndex
        confirmItem = null
        confirmIndex = -1
        menuCard.prepareLayout()
    }

    function back(): void {
        if (confirmItem) {
            cancelConfirmation()
            return
        }

        if (page === "monitor") {
            page = "system"
            selectedIndex = 0
            menuCard.prepareLayout()
            return
        }

        close()
    }

    function selectNext(): void {
        if (currentItems.length === 0)
            return

        selectedIndex = (selectedIndex + 1) % currentItems.length
    }

    function selectPrevious(): void {
        if (currentItems.length === 0)
            return

        selectedIndex =
            (selectedIndex - 1 + currentItems.length)
            % currentItems.length
    }

    function activateIndex(index): void {
        if (confirmItem) {
            const pending = confirmItem
            if (index === 0) {
                close()
                if (pending.command)
                    config.run(pending.command)
            } else {
                cancelConfirmation()
            }
            return
        }

        if (index < 0 || index >= currentItems.length)
            return

        const item = currentItems[index]

        if (item.confirm) {
            confirmItem = item
            confirmIndex = index
            selectedIndex = 1
            menuCard.prepareLayout()
            return
        }

        if (item.action === "wallpaper") {
            const screen = menuWindow.screen
            close()
            wallpaperPicker.open(screen)
            return
        }

        if (item.action === "idleSettings") {
            const screen = menuWindow.screen
            close()
            idleService.openSettings(screen)
            return
        }

        if (item.action === "suspend") {
            close()
            idleService.suspend()
            return
        }

        if (item.action === "lock") {
            close()
            lockService.lock()
            return
        }

        if (item.page) {
            page = item.page
            selectedIndex = 0
            menuCard.prepareLayout()
            return
        }

        if (item.command) {
            close()
            config.run(item.command)
        }
    }

    function activateSelected(): void {
        activateIndex(selectedIndex)
    }

    // Popup frame and keyboard focus scope for the selected page.
    PanelWindow {
        id: menuWindow

        screen: root.menuScreen || root.targetScreen

        anchors {
            top: true
            left: true
        }

        implicitWidth: menuCard.implicitWidth
        implicitHeight: menuCard.implicitHeight
        margins.top: root.config.popupGap
        margins.left: screen
            ? Math.max(0, Math.round((screen.width - menuCard.implicitWidth) / 2)) : 0

        visible: popupMotion.surfaceVisible
        color: "transparent"
        exclusiveZone: 0
        focusable: root.opened

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "slim-submenu"
        WlrLayershell.keyboardFocus: root.opened
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        PopupMotion {
            id: popupMotion
            duration: root.config.popupDuration
            surfaceHeight: menuWindow.height
            shown: root.opened
            animationsEnabled: root.config.popupAnimations
            animationType: root.config.popupAnimationStyle
            onClosed: root.menuScreen = null
        }

        FocusScope {
            id: keyboardHandler

            anchors.fill: parent
            focus: true
            enabled: root.opened

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Left:
                    if (root.page === "power") {
                        root.selectPrevious()
                        event.accepted = true
                    }
                    return
                case Qt.Key_Right:
                    if (root.page === "power") {
                        root.selectNext()
                        event.accepted = true
                    }
                    return
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
                    root.back()
                    event.accepted = true
                    return
                }

                const key = event.text.toLowerCase()

                for (let i = 0; i < root.currentItems.length; ++i) {
                    if (root.currentItems[i].shortcut === key) {
                        root.activateIndex(i)
                        event.accepted = true
                        return
                    }
                }

            }
        }

        PopoutPanel {
            id: menuCard

            enabled: root.opened
            opacity: popupMotion.contentOpacity
            transform: Translate {
                y: popupMotion.contentOffset
            }

            z: 1
            config: root.config
            contentWidth: 260
            padding: 12
            spacing: 4

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter


            Text {
                renderType: Text.NativeRendering
                width: parent.width
                visible: root.confirmItem !== null
                color: root.config.urgent
                font.pointSize: root.config.fontSize(0.9)
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                text: root.confirmItem ? root.confirmItem.label + "?" : ""
            }

            // Highlighted row, icon, label, and shortcut hint.
            Repeater {
                model: root.currentItems

                delegate: Item {
                    id: menuItem

                    required property var modelData
                    required property int index

                    width: parent ? parent.width : 0
                    height: 32

                    readonly property bool selected:
                        root.selectedIndex === index

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
                        horizontalAlignment: Text.AlignHCenter

                        color: menuItem.selected
                            ? root.config.selectionForeground : root.config.selectionBackground
                        font.family: root.config.iconFontFamily
                        font.pointSize: root.config.iconSize * 1.077
                        text: modelData.icon ?? ""
                    }

                    Text {
                        renderType: Text.NativeRendering
                        anchors.left: parent.left
                        anchors.leftMargin: 38
                        anchors.right: keyHint.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        color: menuItem.selected
                            ? root.config.selectionForeground : root.config.fg
                        font.pointSize: root.config.fontSize(1)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        text: modelData.label
                    }

                    Text {
                        visible: modelData.page !== undefined
                        anchors.right: keyHint.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        color: menuItem.selected
                            ? root.config.selectionForeground : root.config.muted
                        font.family: root.config.iconFontFamily
                        font.pointSize: root.config.iconSize
                        text: "󰅂"
                    }

                    Text {
                        renderType: Text.NativeRendering
                        id: keyHint

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 21
                        horizontalAlignment: Text.AlignHCenter
                        color: menuItem.selected
                            ? root.config.selectionForeground : root.config.fg
                        font.pointSize: root.config.fontSize(0.846)
                        text: modelData.shortcut ?? ""
                    }

                }
            }
        }

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => keyboardHandler.forceActiveFocus())
        }
    }

    PopupCatcher {
        targetScreen: menuWindow.screen
        visible: menuWindow.visible
        onDismissed: root.close()
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle("power", root.targetScreen)
        }

        function open(): void {
            root.open("power")
        }

        function close(): void {
            if (root.page === "power")
                root.close()
        }
    }

    IpcHandler {
        target: "menu"


        function packages(): void {
            root.open("packages")
        }

        function settings(): void {
            root.open("settings")
        }

        function system(): void {
            root.open("system")
        }

        function close(): void {
            root.close()
        }
    }
}
