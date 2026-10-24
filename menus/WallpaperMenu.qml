pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components"

PanelWindow {
    id: root

    required property var config
    required property var targetScreen
    required property var controller
    property string scanError: ""
    property string scanNotice: ""
    property bool scanFinished: false
    property string selectedPath: ""
    property bool settingsOpen: false
    property string promptError: ""
    readonly property var actions: [
        { label: "Set Wallpaper", key: "b", action: "wallpaper", control: false },
        { label: "Hellwal", key: "h", action: "hellwal", control: false },
        { label: "Settings", key: "s", action: "settings", control: false }
    ]
    readonly property int selectedIndex: {
        if (visibleEntries.count === 0)
            return -1
        for (let i = 0; i < visibleEntries.count; ++i) {
            if (visibleEntries.get(i).path === selectedPath)
                return i
        }
        return 0
    }
    readonly property var selected: selectedIndex >= 0 && selectedIndex < visibleEntries.count
        ? visibleEntries.get(selectedIndex) : null

    signal closeRequested()

    ListModel { id: allEntries }
    ListModel { id: visibleEntries }

    function matches(entry) {
        return entry.name.toLowerCase().includes(search.text.trim().toLowerCase())
    }

    function addEntry(entry) {
        allEntries.append(entry)
        if (matches(entry))
            visibleEntries.append(entry)
    }

    function filterEntries() {
        visibleEntries.clear()
        for (let i = 0; i < allEntries.count; ++i) {
            const entry = allEntries.get(i)
            if (matches(entry))
                visibleEntries.append({path: entry.path, name: entry.name, thumbnail: entry.thumbnail})
        }
        selectedPath = ""
        grid.positionViewAtBeginning()
    }

    function moveSelection(delta) {
        if (visibleEntries.count === 0)
            return
        const index = Math.max(0, Math.min(visibleEntries.count - 1, selectedIndex + delta))
        selectedPath = visibleEntries.get(index).path
        grid.positionViewAtIndex(index, GridView.Contain)
    }

    function applySelection(hellwal) {
        if (selected)
            controller.apply(selected.path, hellwal)
    }

    function openSettings() {
        promptError = ""
        modeInput.currentIndex = controller.settingsService.hellwalMode === "light" ? 1 : 0
        darkOffsetInput.text = String(controller.settingsService.hellwalDarkOffset)
        brightOffsetInput.text = String(controller.settingsService.hellwalBrightOffset)
        settingsOpen = true
        Qt.callLater(() => {
            modeInput.forceActiveFocus()
        })
    }

    function saveSettings() {
        if (controller.busy)
            return
        const dark = Number(darkOffsetInput.text.trim())
        const bright = Number(brightOffsetInput.text.trim())
        if (darkOffsetInput.text.trim() === "" || brightOffsetInput.text.trim() === ""
            || !Number.isFinite(dark) || !Number.isFinite(bright)
            || dark < 0 || dark > 1 || bright < 0 || bright > 1) {
            promptError = "Offsets must be between 0 and 1"
            return
        }
        promptError = controller.settingsService.saveHellwalSettings(
            modeInput.currentIndex === 1 ? "light" : "dark", dark, bright)
        if (promptError !== "")
            return
        settingsOpen = false
        grid.forceActiveFocus()
    }

    function activateAction(action) {
        if (action === "settings")
            openSettings()
        else
            applySelection(action === "hellwal")
    }

    function handleEscape() {
        if (settingsOpen) {
            settingsOpen = false
            promptError = ""
            grid.forceActiveFocus()
        } else if (search.activeFocus) {
            grid.forceActiveFocus()
        } else {
            closeRequested()
        }
    }

    function navigate(event) {
        const columns = Math.max(1, Math.floor(grid.width / grid.cellWidth))
        switch (event.key) {
        case Qt.Key_Left: moveSelection(-1); break
        case Qt.Key_Right: moveSelection(1); break
        case Qt.Key_Up: moveSelection(-columns); break
        case Qt.Key_Down: moveSelection(columns); break
        default: return
        }
        event.accepted = true
    }

    screen: targetScreen
    visible: true
    color: "transparent"
    implicitWidth: targetScreen ? Math.min(660, targetScreen.width - 32) : 660
    implicitHeight: targetScreen ? Math.min(570, targetScreen.height - config.popupGap - 24) : 570
    exclusiveZone: 0
    focusable: true
    anchors.top: true
    anchors.left: true
    margins.top: config.popupGap
    margins.left: targetScreen ? Math.max(0, Math.round((targetScreen.width - width) / 2)) : 0
    WlrLayershell.namespace: "slim-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: Qt.callLater(() => grid.forceActiveFocus())
    Component.onDestruction: {
        if (scanProcess.running)
            scanProcess.signal(15)
    }

    Shortcut { sequence: "Escape"; onActivated: root.handleEscape() }
    Shortcut {
        sequence: "B"
        enabled: !search.activeFocus && !root.settingsOpen && !!root.selected && !root.controller.busy
        onActivated: root.applySelection(false)
    }
    Shortcut {
        sequence: "H"
        enabled: !search.activeFocus && !root.settingsOpen && !!root.selected && !root.controller.busy
        onActivated: root.applySelection(true)
    }
    Shortcut {
        sequence: "S"
        enabled: !search.activeFocus && !root.settingsOpen
        onActivated: root.openSettings()
    }

    Process {
        id: scanProcess
        command: ["python3", root.controller.helperPath, "list", "--directory", root.controller.directory]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const record = JSON.parse(data)
                    if (record.path) {
                        root.addEntry(record)
                    } else if (record.done) {
                        root.scanFinished = true
                        if (record.failed)
                            root.scanNotice = record.failed + " thumbnail(s) unavailable"
                    } else if (record.error) {
                        root.scanError = record.error
                    }
                } catch (error) {
                    root.scanError = "Could not read wallpaper list"
                }
            }
        }
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (!root.scanFinished && root.scanError === "")
                root.scanError = "Could not finish loading wallpapers"
        }
    }

    PopupCatcher {
        targetScreen: root.targetScreen
        visible: root.visible
        onDismissed: root.closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        color: root.config.bg
        border.color: root.config.selectionBackground
        border.width: 1
        radius: root.config.popupRadius

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            TextField {
                renderType: Text.NativeRendering
                id: search
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                placeholderText: "Search wallpapers…"
                color: root.config.fg
                placeholderTextColor: root.config.muted
                selectionColor: root.config.selectionBackground
                selectedTextColor: root.config.selectionForeground
                font.pointSize: root.config.fontSize(0.92)
                selectByMouse: true
                enabled: !root.settingsOpen
                KeyNavigation.priority: KeyNavigation.BeforeItem
                KeyNavigation.tab: grid
                KeyNavigation.backtab: grid
                onTextChanged: root.filterEntries()
                onAccepted: grid.forceActiveFocus()
                background: Rectangle {
                    color: "transparent"
                    radius: 4
                    border.color: root.config.selectionBackground
                }
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Up:
                    case Qt.Key_Down:
                        grid.forceActiveFocus()
                        root.navigate(event)
                        break
                    default: return
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / Math.max(1, Math.floor(width / 190))
                cellHeight: 145
                model: visibleEntries
                keyNavigationEnabled: false
                reuseItems: true
                cacheBuffer: 145
                enabled: !root.settingsOpen
                activeFocusOnTab: true
                KeyNavigation.priority: KeyNavigation.BeforeItem
                KeyNavigation.tab: search
                KeyNavigation.backtab: search
                Keys.onPressed: event => root.navigate(event)

                delegate: Item {
                    id: tile
                    required property string path
                    required property string name
                    required property string thumbnail
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 4
                        color: root.config.bg
                        border.width: root.selectedIndex === tile.index ? 2 : 1
                        border.color: Qt.alpha(root.config.selectionBackground,
                            root.selectedIndex === tile.index ? 1 : 0.5)

                        Image {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 4
                            height: parent.height - 30
                            source: tile.thumbnail
                            sourceSize.width: 384
                            sourceSize.height: 216
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Text {
                            renderType: Text.NativeRendering
                            anchors.centerIn: parent
                            visible: tile.thumbnail === ""
                            text: "No preview"
                            color: root.config.muted
                            font.pointSize: root.config.fontSize(0.8)
                        }

                        Text {
                            renderType: Text.NativeRendering
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 7
                            text: tile.name
                            elide: Text.ElideMiddle
                            color: root.config.fg
                            font.pointSize: root.config.fontSize(0.8)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedPath = tile.path
                            grid.forceActiveFocus()
                        }
                        onDoubleClicked: root.applySelection(false)
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    visible: visibleEntries.count === 0
                    text: scanProcess.running ? "Loading wallpapers…"
                        : allEntries.count ? "No matching wallpapers" : "No wallpapers found"
                    color: root.config.muted
                    font.pointSize: root.config.fontSize(0.9)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.settingsOpen
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        renderType: Text.NativeRendering
                        text: "Settings"
                        color: root.config.fg
                        font.pointSize: root.config.fontSize(0.9)
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        renderType: Text.NativeRendering
                        text: "Mode"
                        color: root.config.muted
                        font.pointSize: root.config.fontSize(0.8)
                    }
                    ComboBox {
                        id: modeInput
                        Layout.preferredWidth: 100
                        model: ["dark", "light"]
                        currentIndex: 0
                        enabled: !root.controller.busy
                        contentItem: Text {
                            renderType: Text.NativeRendering
                            leftPadding: 8
                            verticalAlignment: Text.AlignVCenter
                            text: modeInput.displayText
                            color: root.config.fg
                            font.pointSize: root.config.fontSize(0.85)
                        }
                        background: Rectangle {
                            radius: 4
                            color: "transparent"
                            border.color: root.config.selectionBackground
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        renderType: Text.NativeRendering
                        text: "Dark offset"
                        color: root.config.muted
                        font.pointSize: root.config.fontSize(0.8)
                    }
                    TextField {
                        id: darkOffsetInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: root.config.fg
                        placeholderText: "0"
                        placeholderTextColor: root.config.muted
                        selectionColor: root.config.selectionBackground
                        selectedTextColor: root.config.selectionForeground
                        enabled: !root.controller.busy
                        onTextChanged: root.promptError = ""
                        background: Rectangle {
                            radius: 4
                            color: "transparent"
                            border.color: root.config.selectionBackground
                        }
                    }
                    Text {
                        renderType: Text.NativeRendering
                        text: "Bright offset"
                        color: root.config.muted
                        font.pointSize: root.config.fontSize(0.8)
                    }
                    TextField {
                        id: brightOffsetInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: root.config.fg
                        placeholderText: "0"
                        placeholderTextColor: root.config.muted
                        selectionColor: root.config.selectionBackground
                        selectedTextColor: root.config.selectionForeground
                        enabled: !root.controller.busy
                        onTextChanged: root.promptError = ""
                        background: Rectangle {
                            radius: 4
                            color: "transparent"
                            border.color: root.config.selectionBackground
                        }
                    }
                    Text {
                        renderType: Text.NativeRendering
                        text: "Save"
                        color: root.config.selectionBackground
                        font.pointSize: root.config.fontSize(0.85)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveSettings()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: root.config.selectionBackground
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                Text {
                    renderType: Text.NativeRendering
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - actionTips.width - 12)
                    text: root.promptError || root.controller.errorText || root.scanError
                        || (root.controller.busy ? "Applying wallpaper…" : root.controller.noticeText)
                        || (scanProcess.running ? "Building thumbnails… " + allEntries.count : root.scanNotice)
                        || visibleEntries.count + " wallpapers"
                    color: root.promptError || root.controller.errorText || root.scanError ? root.config.urgent : root.config.muted
                    font.pointSize: root.config.fontSize(0.78)
                    elide: Text.ElideRight
                    ToolTip.visible: statusHover.hovered && truncated
                    ToolTip.text: text
                    ToolTip.delay: 500

                    HoverHandler { id: statusHover }
                }

                Row {
                    id: actionTips
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Repeater {
                        model: root.actions
                        delegate: Item {
                            id: hint
                            required property var modelData
                            readonly property bool hovered: enabled && hintMouse.containsMouse
                            width: hintRow.width
                            height: 20
                            opacity: enabled ? 1 : 0.5
                            enabled: (hint.modelData.action === "settings" || !!root.selected)
                                && !root.controller.busy && !root.settingsOpen

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: 4
                                color: hint.hovered ? root.config.selectionBackground : "transparent"
                            }

                            Row {
                                id: hintRow
                                spacing: 5
                                Text {
                                    renderType: Text.NativeRendering
                                    height: 20
                                    verticalAlignment: Text.AlignVCenter
                                    text: hint.modelData.label
                                    color: hint.hovered
                                        ? root.config.selectionForeground : root.config.muted
                                    font.pointSize: root.config.fontSize(0.8)
                                }
                                KeyCap {
                                    visible: hint.modelData.control
                                    label: "Ctrl"
                                    edgeColor: root.config.selectionBackground
                                    textColor: hint.hovered
                                        ? root.config.selectionForeground : root.config.muted
                                    fontPointSize: root.config.fontSize(0.74)
                                }
                                KeyCap {
                                    label: hint.modelData.key
                                    edgeColor: root.config.selectionBackground
                                    textColor: hint.hovered
                                        ? root.config.selectionForeground : root.config.muted
                                    fontPointSize: root.config.fontSize(0.74)
                                }
                            }
                            MouseArea {
                                id: hintMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateAction(hint.modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }

    component KeyCap: Rectangle {
        property string label: ""
        property color edgeColor: "gray"
        property color textColor: "gray"
        property real fontPointSize: 9
        implicitHeight: 20
        implicitWidth: Math.max(implicitHeight, capText.implicitWidth + 12)
        radius: 4
        color: "transparent"
        border.width: 1
        border.color: edgeColor

        Text {
            renderType: Text.NativeRendering
            id: capText
            anchors.centerIn: parent
            text: parent.label
            color: parent.textColor
            font.pointSize: parent.fontPointSize
        }
    }
}
