import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

import "Scorer.js" as Scorer

Item {
    id: root

    visible: false

    required property var config
    required property var targetScreen

    property bool opened: false
    property bool quitOnClose: false

    // Height animation is only enabled while the launcher is on screen, so
    // resetting state on close/open never animates a stale, expanded card.
    property bool animateHeight: false

    readonly property string placeholder:
        fileMode ? "Search files" : "Search applications"

    property string query: ""
    property string calculatorResult: ""
    property var fileResults: []
    property int selectedIndex: 0

    readonly property int maxVisibleRows: 7
    readonly property int rowHeight: 46
    readonly property int inputHeight: 50
    readonly property int contentWidth: 560
    readonly property bool fileMode: query.trim().startsWith("/")
    readonly property string fileNeedle:
        fileMode ? query.trim().slice(1).trim() : ""

    readonly property bool calculatorQuery: {
        const value = query.trim()
        return !fileMode
            && /[0-9]/.test(value)
            && /[+\-*/%^]/.test(value)
            && /^[0-9\s+\-*/%^().,]+$/.test(value)
    }

    readonly property var applications: {
        const seen = new Set()

        return [...DesktopEntries.applications.values]
            .filter(entry => {
                if (!entry || !entry.id || seen.has(entry.id))
                    return false

                seen.add(entry.id)
                return true
            })
    }

    readonly property var results: {
        const value = query.trim().toLowerCase()
        let entries = []

        if (fileMode) {
            entries = fileResults
        } else if (value !== "") {
            entries = applications
                .map(entry => ({
                    type: "application",
                    entry: entry,
                    text: entry.name || entry.id,
                    subtitle: entry.genericName || entry.comment || "",
                    icon: entry.icon || "",
                    score: Scorer.scoreApplication(entry, value)
                }))
                .filter(item => item.score > 0)
                .sort((a, b) => b.score - a.score
                    || a.text.localeCompare(b.text))
        }

        if (calculatorResult !== "") {
            entries.unshift({
                type: "calculator",
                text: calculatorResult,
                subtitle: query.trim(),
                icon: "󰃬"
            })
        }

        return entries.slice(0, 100)
    }

    readonly property bool expanded: query.trim() !== ""
    readonly property bool fileSearching:
        fileProcess.running || fileSearchDebounce.running
    readonly property int visibleRows:
        expanded
            ? Math.max(1, Math.min(maxVisibleRows, results.length))
            : 0

    function close(): void {
        finalizeClose()
    }

    function finalizeClose(): void {
        // Collapse the card with animation off *before* hiding, so the next
        // toggle starts from an empty, collapsed launcher.
        animateHeight = false
        opened = false
        reset()

        if (quitOnClose)
            Qt.quit()
    }

    function reset(): void {
        query = ""
        calculatorResult = ""
        fileResults = []
        selectedIndex = 0
        searchInput.text = ""
    }

    function openApplications(): void {
        animateHeight = false
        reset()
        opened = true

        Qt.callLater(() => {
            searchInput.forceActiveFocus()
            animateHeight = true
        })
    }

    function toggleApplications(): void {
        opened ? close() : openApplications()
    }

    function selectNext(): void {
        if (results.length > 0) {
            selectedIndex = (selectedIndex + 1) % results.length
            resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function selectPrevious(): void {
        if (results.length > 0) {
            selectedIndex =
                (selectedIndex - 1 + results.length) % results.length
            resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function selectPage(direction): void {
        if (results.length === 0)
            return

        selectedIndex = Math.max(
            0,
            Math.min(results.length - 1, selectedIndex + direction * visibleRows)
        )
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function activateSelected(): void {
        if (selectedIndex < 0 || selectedIndex >= results.length)
            return

        const item = results[selectedIndex]

        if (item.type === "application") {
            item.entry.execute()
            finalizeClose()
        } else if (item.type === "calculator") {
            Quickshell.execDetached(["wl-copy", item.text])
            finalizeClose()
        } else if (item.type === "file") {
            openFile(item.path)
        }
    }

    // Replaces open-file.sh: detect the mime type, then either edit the file
    // in a terminal (text/config/scripts) or hand it to xdg-open.
    function openFile(path): void {
        if (mimeProcess.running)
            return

        mimeProcess.path = path
        mimeProcess.command = ["file", "--mime-type", "-b", "--", path]
        mimeProcess.running = true
    }

    function launchFile(path, mime): void {
        const home = Quickshell.env("HOME") || ""
        const editor = Quickshell.env("EDITOR") || "nvim"
        const terminal = Quickshell.env("TERMINAL") || "foot"

        const isText = mime.startsWith("text/")
            || /\.(sh|py|conf)$/.test(path)

        if (!isText) {
            Quickshell.execDetached(["xdg-open", path])
        } else if (home !== "" && path.startsWith(home + "/")) {
            Quickshell.execDetached([terminal, "-e", editor, path])
        } else {
            Quickshell.execDetached([terminal, "-e", "sudoedit", path])
        }
    }

    function updateCalculator(): void {
        calculatorResult = ""

        if (calculatorQuery)
            calculatorDebounce.restart()
        else
            calculatorDebounce.stop()
    }

    function updateFileSearch(): void {
        fileResults = []
        fileSearchDebounce.stop()

        if (fileProcess.running) {
            fileProcess.signal(15)
            return
        }

        if (fileMode && fileNeedle.length >= 2)
            fileSearchDebounce.restart()
    }

    function fileItem(path): var {
        const parts = path.split("/")
        return {
            type: "file",
            path: path,
            text: parts[parts.length - 1] || path,
            subtitle: path,
            icon: ""
        }
    }

    PanelWindow {
        id: launcherWindow

        screen: root.targetScreen
        visible: root.opened
        color: "transparent"
        exclusiveZone: 0
        focusable: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => searchInput.forceActiveFocus())
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card

            width: root.contentWidth
            height: root.inputHeight
                + (root.expanded ? root.visibleRows * root.rowHeight + 8 : 0)

            anchors.top: parent.top
            anchors.topMargin: 120
            anchors.horizontalCenter: parent.horizontalCenter

            color: root.config.surface
            border.color: root.config.borderColor
            border.width: 1
            radius: root.config.popupRadius
            clip: true

            Behavior on height {
                enabled: root.animateHeight

                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            TextInput {
                id: searchInput

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.inputHeight
                leftPadding: 18
                rightPadding: 18

                focus: true
                verticalAlignment: TextInput.AlignVCenter
                color: root.config.fg
                selectionColor: root.config.accent
                selectedTextColor: root.config.bg
                font.pointSize: root.config.fontSize(1.08)
                clip: true

                onTextChanged: {
                    root.query = text
                    root.selectedIndex = 0
                    root.updateCalculator()
                    root.updateFileSearch()
                }

                Keys.onPressed: event => {
                    const control = event.modifiers & Qt.ControlModifier

                    switch (event.key) {
                    case Qt.Key_Down:
                        root.selectNext()
                        event.accepted = true
                        break
                    case Qt.Key_Up:
                        root.selectPrevious()
                        event.accepted = true
                        break
                    case Qt.Key_J:
                        if (control) {
                            root.selectNext()
                            event.accepted = true
                        }
                        break
                    case Qt.Key_K:
                        if (control) {
                            root.selectPrevious()
                            event.accepted = true
                        }
                        break
                    case Qt.Key_PageDown:
                        root.selectPage(1)
                        event.accepted = true
                        break
                    case Qt.Key_PageUp:
                        root.selectPage(-1)
                        event.accepted = true
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.activateSelected()
                        event.accepted = true
                        break
                    case Qt.Key_Escape:
                        root.close()
                        event.accepted = true
                        break
                    }
                }

                Component.onCompleted: forceActiveFocus()
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: searchInput.verticalCenter
                visible: searchInput.text.length === 0

                color: root.config.muted
                font.pointSize: root.config.fontSize(1.08)
                text: root.placeholder
            }

            Rectangle {
                anchors.top: searchInput.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.expanded ? 1 : 0
                color: root.config.borderColor
            }

            ListView {
                id: resultList

                anchors.top: searchInput.bottom
                anchors.topMargin: 5
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 4

                visible: root.expanded
                clip: true
                interactive: contentHeight > height
                model: root.results
                currentIndex: root.selectedIndex

                delegate: Item {
                    id: resultRow

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: root.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: resultRow.index === root.selectedIndex
                            || rowMouse.containsMouse
                            ? root.config.borderColor
                            : "transparent"
                    }

                    IconImage {
                        id: appIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 26
                        visible: source.toString() !== ""
                        source: modelData.icon
                            ? Quickshell.iconPath(modelData.icon, true)
                            : ""
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.type === "calculator"
                            || modelData.type === "file"

                        color: root.config.accent
                        font.family: root.config.iconFontFamily
                        font.pointSize: root.config.iconSize
                        text: modelData.type === "file" ? "󰈔" : "󰃬"
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 50
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width

                            color: root.config.fg
                            font.pointSize: root.config.fontSize(0.96)
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            text: modelData.text
                        }

                        Text {
                            width: parent.width
                            visible: (modelData.subtitle || "") !== ""

                            color: root.config.muted
                            font.pointSize: root.config.fontSize(0.74)
                            elide: Text.ElideRight
                            text: modelData.subtitle || ""
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = resultRow.index
                        onClicked: root.activateSelected()
                    }
                }
            }

            Text {
                anchors.top: searchInput.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.expanded && root.results.length === 0

                color: root.config.muted
                font.pointSize: root.config.fontSize(0.88)
                text: root.fileMode && root.fileNeedle.length < 2
                    ? "Type at least two characters after /"
                    : root.fileMode && root.fileSearching ? "Searching…"
                    : root.fileMode ? "No files found"
                    : "No applications found"
            }
        }
    }

    Timer {
        id: calculatorDebounce
        interval: 120
        onTriggered: {
            if (calculatorProcess.running)
                return

            calculatorProcess.expression = root.query.trim()
            calculatorProcess.command = [
                "qalc", "-t", calculatorProcess.expression
            ]
            calculatorProcess.running = true
        }
    }

    Process {
        id: calculatorProcess

        property string expression: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim().split("\n")[0] || ""

                if (calculatorProcess.expression === root.query.trim()) {
                    root.calculatorResult = value
                    root.selectedIndex = 0
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.calculatorResult = ""

            if (root.calculatorQuery
                    && calculatorProcess.expression !== root.query.trim()) {
                calculatorDebounce.restart()
            }
        }
    }

    Timer {
        id: fileSearchDebounce
        interval: 180
        onTriggered: {
            if (fileProcess.running || root.fileNeedle.length < 2)
                return

            fileProcess.needle = root.fileNeedle
            fileProcess.command = [
                "fd", "-H", "-t", "f",
                "--max-results", "100",
                "--exclude", "*.png",
                "--exclude", "*.jpg",
                "--exclude", "*.jpeg",
                "--exclude", "*.webp",
                "--exclude", "*.gif",
                "--exclude", "*.bmp",
                "--exclude", "*.svg",
                "--exclude", "*.mp4",
                "--exclude", "*.mkv",
                "--exclude", "*.webm",
                "--exclude", "*.mov",
                "--exclude", "*.avi",
                "--exclude", "*.ttf",
                "--exclude", "*.otf",
                "--exclude", "*.woff",
                "--exclude", "*.woff2",
                "--exclude", "*.so",
                "--exclude", "*.so.*",
                "--exclude", "*.exe",
                "--exclude", "*.dll",
                "--exclude", "*.zip",
                "--exclude", "*.7z",
                "--exclude", "*.tar",
                "--exclude", "*.gz",
                "--",
                fileProcess.needle,
                Quickshell.env("HOME") + "/.config",
                Quickshell.env("HOME") + "/.local/bin",
                "/etc"
            ]
            fileProcess.running = true
        }
    }

    Process {
        id: fileProcess

        property string needle: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (fileProcess.needle !== root.fileNeedle)
                    return

                root.fileResults = text.trim()
                    .split("\n")
                    .filter(path => path.length > 0)
                    .map(path => root.fileItem(path))
                root.selectedIndex = 0
            }
        }

        stderr: StdioCollector {}

        onExited: {
            if (root.fileMode
                    && root.fileNeedle.length >= 2
                    && fileProcess.needle !== root.fileNeedle) {
                fileSearchDebounce.restart()
            }
        }
    }

    Process {
        id: mimeProcess

        property string path: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const mime = text.trim()

                // Empty output means `file` failed (e.g. path vanished).
                if (mime !== "")
                    root.launchFile(mimeProcess.path, mime)

                root.finalizeClose()
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggleApplications()
        }

        function open(): void {
            root.openApplications()
        }

        function close(): void {
            root.close()
        }
    }
}
