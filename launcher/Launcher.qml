import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

import "Scorer.js" as Scorer
import "Dmenu.js" as Dmenu

Item {
    id: root

    visible: false

    required property var config
    required property var targetScreen
    required property var timerService

    property bool opened: false
    property bool quitOnClose: false
    // Mode order for Ctrl+← / Ctrl+→ cycling.
    readonly property var modes: ["apps", "run", "emoji", "timer"]
    property string mode: "apps"
    readonly property bool runMode: mode === "run"
    readonly property bool emojiMode: mode === "emoji"
    readonly property bool timerMode: mode === "timer"
    // dmenu mode is entered only through `qs ipc call launcher dmenu`, so it
    // is not part of `modes` and can't be reached by cycling.
    readonly property bool dmenuMode: mode === "dmenu"
    property var dmenuItems: []
    property string dmenuPrompt: ""
    property int dmenuLines: 7
    property bool dmenuMinimalLines: false
    property bool dmenuIndexMode: false
    // Result file awaited by the caller; empty when no request is pending.
    property string dmenuOutPath: ""
    readonly property string dmenuSessionId: Date.now().toString() + "-" + Math.random().toString()
    property double timerClock: Date.now()

    // App IDs only, newest first; separate from binary run history.
    property var appHistory: []
    property bool appHistoryReady: false
    readonly property int appHistoryKept: 50
    readonly property string appHistoryPath:
        (Quickshell.env("HOME") || "") + "/.cache/quickshell-app-history.json"
    readonly property var appHistoryRanks: {
        const ranks = new Map()
        for (let i = 0; i < appHistory.length; ++i)
            ranks.set(appHistory[i], i)
        return ranks
    }

    // Nerd font glyphs
    readonly property string iconRun: String.fromCodePoint(0xF018D)
    readonly property string iconStar: String.fromCodePoint(0xF04CE)

    readonly property string placeholder: dmenuMode
        ? (dmenuPrompt !== "" ? dmenuPrompt : "Select")
        : runMode
        ? "Search binaries"
        : timerMode ? "Set a timer (e.g. 25m Focus)"
        : emojiMode ? "Search emoji"
        : fileMode ? "Search files" : "Search applications"

    property string query: ""
    readonly property string calculatorResult: calculator.result
    property int selectedIndex: 0

    readonly property int maxVisibleRows: 7
    readonly property int rowHeight: 46
    readonly property int inputHeight: 50
    readonly property int contentWidth: 400
    readonly property int contentSpacing: 8
    readonly property bool fileMode:
        !runMode && !emojiMode && !timerMode && !dmenuMode
        && query.trim().startsWith("/")
    readonly property string fileNeedle:
        fileMode ? query.trim().slice(1).trim() : ""

    // "=" prefix hands everything after it to qalc, so units, functions and
    // words work too ("=5 km to miles", "=sqrt(2)", "=1x3").
    readonly property bool calcPrefix:
        !runMode && !emojiMode && !timerMode && !dmenuMode
        && query.trim().startsWith("=")
    readonly property string calcExpression:
        calcPrefix ? query.trim().slice(1).trim() : query.trim()

    // Plain math without the prefix is still detected automatically.
    readonly property bool calculatorQuery: {
        if (calcPrefix)
            return calcExpression.length > 0

        const value = query.trim()
        return !runMode
            && !emojiMode
            && !timerMode
            && !dmenuMode
            && !fileMode
            && /[0-9]/.test(value)
            && (/[+\-*/%^×÷]/.test(value)
                || /\d\s*[xX]\s*[\d(.]/.test(value))
            && /^[0-9\s+\-*/%^().,xX×÷]+$/.test(value)
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

    readonly property var dmenuResults: {
        if (!opened || !dmenuMode)
            return []

        const toItem = (line, index, score) => ({
            type: "dmenu",
            text: line,
            subtitle: "",
            icon: "",
            index: index,
            score: score
        })

        const value = query.trim().toLowerCase()

        // Keep the caller's order until something is typed.
        if (value === "")
            return dmenuItems.map((line, i) => toItem(line, i, 0))

        return dmenuItems
            .map((line, i) => toItem(line, i, Scorer.scoreLine(line, value)))
            .filter(item => item.score > 0)
            .sort((a, b) => b.score - a.score || a.index - b.index)
    }

    readonly property var timerInput: opened && timerMode ? parseTimer(query) : null

    readonly property var timerResults: {
        if (!opened || !timerMode)
            return []

        if (query.trim() !== "") {
            if (!timerInput)
                return []

            return [{
                type: "timer-start",
                text: formatDuration(timerInput.seconds),
                subtitle: timerInput.note || "Press Enter to start",
                icon: "󰔛",
                seconds: timerInput.seconds,
                note: timerInput.note
            }]
        }

        return timerService.timers
            .slice()
            .sort((a, b) => a.endAt - b.endAt)
            .map(timer => ({
                type: "timer-active",
                text: timer.note || "Timer",
                endAt: timer.endAt,
                icon: "󰔛",
                unit: timer.unit
            }))
    }

    readonly property var results: {
        if (!opened)
            return []

        const value = query.trim().toLowerCase()
        let entries = []

        if (dmenuMode) {
            entries = dmenuResults
        } else if (runMode) {
            entries = runState.results
        } else if (emojiMode) {
            entries = emojiState.results
        } else if (timerMode) {
            entries = timerResults
        } else if (calcPrefix) {
            entries = []
        } else if (fileMode) {
            entries = files.results
        } else if (value === "") {
            entries = applications
                .map(entry => ({
                    type: "application",
                    entry: entry,
                    text: entry.name || entry.id,
                    subtitle: entry.genericName || entry.comment || "",
                    icon: entry.icon || "",
                    score: 0
                }))
                .sort((a, b) => applicationRank(a.entry.id) - applicationRank(b.entry.id)
                    || a.text.localeCompare(b.text))
        } else {
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
                    || applicationRank(a.entry.id) - applicationRank(b.entry.id)
                    || a.text.localeCompare(b.text))
        }

        if (!runMode && !timerMode && !dmenuMode && calculatorResult !== "") {
            entries.unshift({
                type: "calculator",
                text: calculatorResult,
                subtitle: calcExpression,
                icon: "󰃬"
            })
        }

        if (dmenuMode)
            return entries

        return !runMode && value === "" ? entries : entries.slice(0, 100)
    }

    onResultsChanged: selectedIndex = Math.max(0,
        Math.min(selectedIndex, results.length - 1))

    // Normal modes stay fixed; dmenu can choose a row count per request.
    readonly property bool fileSearching: files.busy
    readonly property int availableDmenuRows: targetScreen
        ? Math.max(0, Math.floor((targetScreen.height - config.popupGap * 2
            - inputHeight - contentSpacing * 2 - 2) / rowHeight))
        : maxVisibleRows
    readonly property int visibleRows: dmenuMode
        ? Dmenu.visibleRows(dmenuLines, dmenuMinimalLines, dmenuItems.length, availableDmenuRows)
        : maxVisibleRows

    readonly property int cardHeight: inputHeight
        + visibleRows * rowHeight
        + contentSpacing * 2
        + 2


    function close(): void {
        finalizeClose()
    }

    function finalizeClose(): void {
        // Closing without a pick (Esc, toggle, ...) must still release the
        // process waiting on the FIFO.
        cancelDmenu()
        opened = false
        reset()

        if (quitOnClose)
            Qt.quit()
    }

    function reset(): void {
        mode = "apps"
        query = ""
        selectedIndex = 0
        searchInput.text = ""
    }

    function openApplications(): void {
        cancelDmenu()
        reset()
        opened = true

        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    function toggleApplications(): void {
        opened ? close() : openApplications()
    }

    // Called from IPC: the items are read from itemsPath, and the result is
    // written atomically to outPath, awaited by launcher/dmenu-runner.
    function requestDmenu(itemsPath, outPath, prompt, lines, minimalLines, indexMode): void {
        // Hide and clear the previous request before loading new choices.
        finalizeClose()
        dmenuOutPath = outPath
        dmenuPrompt = prompt
        dmenuLines = Math.max(0, lines)
        dmenuMinimalLines = minimalLines
        dmenuIndexMode = indexMode
        dmenuFile.path = ""
        dmenuFile.path = itemsPath
    }

    function beginDmenu(items): void {
        dmenuItems = items
        reset()
        mode = "dmenu"
        opened = true

        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    function writeDmenuOutput(path, value): void {
        Quickshell.execDetached([
            "sh", "-c",
            'umask 077; printf "%s" "$2" > "$1.tmp" && mv -- "$1.tmp" "$1"',
            "dmenu-output", path, value === null ? "cancel\n" : "ok\n" + value + "\n"
        ])
    }

    function submitDmenu(value, inputIndex): void {
        if (dmenuOutPath === "")
            return

        writeDmenuOutput(dmenuOutPath, Dmenu.outputValue(value, dmenuIndexMode, inputIndex))
        dmenuOutPath = ""
        dmenuItems = []
        dmenuPrompt = ""
        finalizeClose()
    }

    function cancelDmenu(): void {
        if (dmenuOutPath === "")
            return

        writeDmenuOutput(dmenuOutPath, null)
        dmenuOutPath = ""
        dmenuItems = []
        dmenuPrompt = ""
    }

    function setMode(id): void {
        if (mode === id || dmenuMode)
            return

        mode = id
        selectedIndex = 0

        if (timerMode) {
            timerClock = Date.now()
            timerService.pruneExpired(timerClock)
        }

        searchInput.forceActiveFocus()
    }

    function cycleMode(direction): void {
        if (dmenuMode)
            return

        const currentIndex = modes.indexOf(mode)
        const nextIndex = (currentIndex + direction + modes.length)
            % modes.length
        setMode(modes[nextIndex])
    }

    function openFileSearch(): void {
        if (dmenuMode)
            return

        setMode("apps")
        searchInput.text = "/"
        searchInput.cursorPosition = 1
        selectedIndex = 0
        searchInput.forceActiveFocus()
    }

    function navigateResults(direction): void {
        if (direction > 0)
            selectNext()
        else
            selectPrevious()
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

        if (item.type === "dmenu") {
            submitDmenu(item.text, item.index)
        } else if (item.type === "timer-start") {
            timerService.startTimer(item.seconds, item.note)
            searchInput.text = ""
            timerClock = Date.now()
        } else if (item.type === "timer-active") {
            timerService.cancelTimer(item.unit)
            timerClock = Date.now()
        } else if (item.type === "application") {
            item.entry.execute()
            recordApplication(item.entry.id)
            finalizeClose()
        } else if (item.type === "calculator") {
            Quickshell.execDetached(["wl-copy", item.text])
            finalizeClose()
        } else if (item.type === "file") {
            files.open(item.path)
        } else if (item.type === "binary") {
            runState.record(item.text)
            Quickshell.execDetached([item.text, ...runState.args])
            finalizeClose()
        } else if (item.type === "emoji") {
            Quickshell.execDetached(["wl-copy", item.emoji])
            emojiState.record(item.emoji)
            finalizeClose()
        }
    }

    function parseTimer(text): var {
        const value = String(text || "").trim()

        if (value === "")
            return null

        const clockMatch = value.match(/^(\d+):([0-5]?\d)(?:\s+(.+))?$/)
        if (clockMatch) {
            const seconds = Number(clockMatch[1]) * 60
                + Number(clockMatch[2])
            return seconds > 0
                ? { seconds: seconds, note: (clockMatch[3] || "").trim() }
                : null
        }

        const unitMatch = value.match(
            /^((?:\d+(?:\.\d+)?\s*[hms]\s*)+)(.*)$/i
        )
        if (unitMatch) {
            let seconds = 0
            const parts = /(\d+(?:\.\d+)?)\s*([hms])/gi
            let part

            while ((part = parts.exec(unitMatch[1])) !== null) {
                const amount = Number(part[1])
                const unit = part[2].toLowerCase()
                seconds += amount * (unit === "h" ? 3600 : unit === "m" ? 60 : 1)
            }

            return seconds > 0
                ? { seconds: Math.ceil(seconds), note: unitMatch[2].trim() }
                : null
        }

        const minutesMatch = value.match(/^(\d+(?:\.\d+)?)(?:\s+(.+))?$/)
        if (!minutesMatch)
            return null

        const seconds = Math.ceil(Number(minutesMatch[1]) * 60)
        return seconds > 0
            ? { seconds: seconds, note: (minutesMatch[2] || "").trim() }
            : null
    }

    function formatDuration(seconds): string {
        if (seconds >= 3600) {
            const hours = Math.floor(seconds / 3600)
            const minutes = Math.floor((seconds % 3600) / 60)
            return hours + "h" + (minutes > 0 ? " " + minutes + "m" : "")
        }

        if (seconds >= 60) {
            const minutes = Math.floor(seconds / 60)
            const remainder = seconds % 60
            return minutes + "m" + (remainder > 0 ? " " + remainder + "s" : "")
        }

        return seconds + "s"
    }

    function formatRemaining(milliseconds): string {
        const seconds = Math.max(0, Math.ceil(milliseconds / 1000))
        return formatDuration(seconds) + " remaining · select to cancel"
    }

    function applicationRank(id): int {
        const rank = appHistoryRanks.get(id)
        return rank === undefined ? appHistoryKept : rank
    }

    function normalizeAppHistory(ids): var {
        const seen = new Set()
        const next = []
        for (const id of ids) {
            if (typeof id !== "string" || id === "" || seen.has(id))
                continue
            seen.add(id)
            next.push(id)
            if (next.length === appHistoryKept)
                break
        }
        return next
    }

    function restoreAppHistory(value): void {
        let stored = []
        try {
            const parsed = JSON.parse(value)
            if (Array.isArray(parsed))
                stored = parsed
        } catch (error) {}

        // Preserve launches made before the initial asynchronous load finishes.
        const pending = !appHistoryReady && appHistory.length > 0
        appHistory = normalizeAppHistory(appHistoryReady ? stored : appHistory.concat(stored))
        appHistoryReady = true
        if (pending)
            appHistoryFile.setText(JSON.stringify(appHistory))
    }

    function recordApplication(id): void {
        const installed = new Set(applications.map(entry => entry.id))
        if (!installed.has(id))
            return
        appHistory = normalizeAppHistory([id].concat(
            appHistory.filter(previous => installed.has(previous))))
        if (appHistoryReady)
            appHistoryFile.setText(JSON.stringify(appHistory))
    }

    CalculatorState {
        id: calculator
        active: root.opened && root.calculatorQuery
        query: root.query.trim()
        expression: root.calcExpression
        onResultReady: root.selectedIndex = 0
    }

    RunState {
        id: runState
        active: root.opened && root.runMode
        query: root.query
        onBinariesLoaded: root.selectedIndex = 0
    }

    EmojiState {
        id: emojiState
        active: root.opened && root.emojiMode
        query: root.query
        onEntriesLoaded: root.selectedIndex = 0
    }

    FileSearchState {
        id: files
        active: root.opened && root.fileMode
        needle: root.fileNeedle
        onResultsReady: root.selectedIndex = 0
        onFileOpened: root.finalizeClose()
    }

    PanelWindow {
        id: launcherWindow


        screen: root.targetScreen
        visible: root.opened
        color: "transparent"
        implicitWidth: root.contentWidth
        implicitHeight: root.cardHeight
        exclusiveZone: 0
        focusable: true
        WlrLayershell.namespace: "slim-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => {
                return searchInput.forceActiveFocus();
            });

        }

        anchors {
            top: true
            left: true
        }

        margins.top: root.config.popupGap
        margins.left: root.targetScreen
            ? Math.max(0, Math.round((root.targetScreen.width - width) / 2))
            : 0

        Rectangle {
            id: card

            anchors.fill: parent
            color: root.config.bg
            border.color: root.config.selectionBackground
            border.width: 1
            radius: root.config.popupRadius
            clip: true

            Rectangle {
                id: searchBackground

                anchors.fill: searchInput
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 8
                color: root.config.bg
                radius: 4
                border.width: 1
                border.color: root.config.selectionBackground
            }

            TextInput {
                renderType: Text.NativeRendering
                id: searchInput

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.inputHeight
                leftPadding: 18
                rightPadding: 18
                topPadding: searchBackground.anchors.topMargin
                bottomPadding: searchBackground.anchors.bottomMargin
                focus: true
                verticalAlignment: TextInput.AlignVCenter
                color: root.config.fg
                selectionColor: root.config.selectionBackground
                selectedTextColor: root.config.selectionForeground
                font.pointSize: root.config.fontSize(1)
                clip: true
                onTextChanged: {
                    root.query = text;
                    root.selectedIndex = 0;
                }
                Keys.onPressed: (event) => {
                    const control = event.modifiers & Qt.ControlModifier;
                    switch (event.key) {
                    case Qt.Key_Left:
                        if (control) {
                            root.cycleMode(-1);
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_Right:
                        if (control) {
                            root.cycleMode(1);
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_Down:
                        root.navigateResults(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        root.navigateResults(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Tab:
                        root.navigateResults(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Backtab:
                        root.navigateResults(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_J:
                        if (control) {
                            root.selectNext();
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_K:
                        if (control) {
                            root.selectPrevious();
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_A:
                        if (control) {
                            root.setMode("apps");
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_B:
                        if (control) {
                            root.setMode("run");
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_E:
                        if (control) {
                            root.setMode("emoji");
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_T:
                        if (control) {
                            root.setMode("timer");
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_S:
                        if (control) {
                            root.openFileSearch();
                            event.accepted = true;
                        }
                        break;
                    case Qt.Key_PageDown:
                        root.selectPage(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_PageUp:
                        root.selectPage(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        // Shift+Enter (or Enter with no result rows) returns typed text.
                        if (root.dmenuMode && ((event.modifiers & Qt.ShiftModifier) || root.visibleRows === 0))
                            root.submitDmenu(searchInput.text);
                        else
                            root.activateSelected();
                        event.accepted = true;
                        break;
                    case Qt.Key_Escape:
                        root.close();
                        event.accepted = true;
                        break;
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }

            Text {
                renderType: Text.NativeRendering
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: searchBackground.verticalCenter
                visible: searchInput.text.length === 0
                color: root.config.muted
                font.pointSize: root.config.fontSize(1)
                text: root.placeholder
            }

            ListView {
                id: resultList

                anchors.top: searchInput.bottom
                anchors.topMargin: root.contentSpacing
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.contentSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: searchBackground.anchors.leftMargin
                anchors.rightMargin: searchBackground.anchors.rightMargin
                clip: true
                interactive: false
                model: root.results
                currentIndex: root.selectedIndex

                delegate: Item {
                    id: resultRow

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: root.rowHeight

                    readonly property bool selected: index === root.selectedIndex

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: resultRow.selected
                            ? root.config.selectionBackground : "transparent"
                    }

                    IconImage {
                        id: appIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 26
                        visible: source.toString() !== ""
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.type === "calculator" || modelData.type === "file" || modelData.type === "binary" || modelData.type === "emoji" || modelData.type === "timer-start" || modelData.type === "timer-active"
                        color: resultRow.selected
                            ? root.config.selectionForeground : root.config.selectionBackground
                        font.family: modelData.type === "emoji" ? root.config.textFontFamily : root.config.iconFontFamily
                        font.pointSize: root.config.iconSize * 1.5
                        text: modelData.type === "emoji" ? modelData.emoji : modelData.type === "file" ? "󰈔" : modelData.type === "binary" ? (modelData.recent ? root.iconStar : root.iconRun) : modelData.type === "timer-start" || modelData.type === "timer-active" ? "󰔛" : "󰃬"
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: modelData.type === "dmenu" ? 12 : 50
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            renderType: Text.NativeRendering
                            width: parent.width
                            color: resultRow.selected
                                ? root.config.selectionForeground : root.config.fg
                            font.pointSize: root.config.fontSize(0.96)
                            font.family: root.config.textFontFamily
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            textFormat: modelData.type === "dmenu" ? Text.RichText : Text.AutoText
                            text: modelData.type === "dmenu"
                                ? Dmenu.richTextWithSymbols(modelData.text, root.config.iconFontFamily)
                                : modelData.text
                        }

                        Text {
                            renderType: Text.NativeRendering
                            width: parent.width
                            visible: modelData.type === "timer-active"
                                || (modelData.subtitle || "") !== ""
                            color: resultRow.selected
                                ? root.config.selectionForeground : root.config.muted
                            font.pointSize: root.config.fontSize(0.74)
                            elide: Text.ElideRight
                            // The model does not depend on the clock: only
                            // this label updates on each countdown tick.
                            text: modelData.type === "timer-active"
                                ? root.formatRemaining(modelData.endAt - root.timerClock)
                                : modelData.subtitle || ""
                        }

                    }

                }

            }

            Text {
                renderType: Text.NativeRendering
                anchors.top: searchInput.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.visibleRows > 0 && root.results.length === 0
                color: root.config.muted
                font.pointSize: root.config.fontSize(0.88)
                    text: root.dmenuMode ? "No matches"
                        : root.calcPrefix
                        ? (root.calcExpression === "" ? "Type an expression"
                            : calculator.busy
                                ? "Calculating…" : "Can't evaluate expression")
                        : root.runMode
                        ? (runState.loading ? "Loading binaries…" : "No binaries found")
                        : root.timerMode
                        ? (root.query.trim() === ""
                            ? "No active timers"
                            : "Try 25m, 45s, 1:30, or 2h Focus")
                        : root.emojiMode ? "No emoji found"
                        : root.fileMode && root.fileNeedle.length < 2
                            ? "Type at least two characters after /"
                            : root.fileMode && root.fileSearching ? "Searching…"
                            : root.fileMode ? "No files found"
                            : "No applications found"
            }

        }

    }

    Timer {
        interval: 1000
        repeat: true
        running: root.opened && root.timerMode
        onTriggered: {
            root.timerClock = Date.now()
            root.timerService.pruneExpired(root.timerClock)
        }
    }

    FileView {
        id: appHistoryFile

        path: root.appHistoryPath
        atomicWrites: true
        printErrors: false
        onLoaded: root.restoreAppHistory(text())
        onLoadFailed: {
            root.appHistoryReady = true
            if (root.appHistory.length > 0)
                setText(JSON.stringify(root.appHistory))
        }
    }

    FileView {
        id: dmenuFile

        printErrors: false
        onLoaded: {
            // Ignore a late load for a request that was already cancelled.
            if (root.dmenuOutPath === "")
                return

            const content = text()
            const lines = content === "" ? [] : content.split("\n")
            // A final newline terminates the last choice, not an extra choice.
            if (content.endsWith("\n"))
                lines.pop()
            root.beginDmenu(lines)
        }
        onLoadFailed: root.close()
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

        function dmenuSession(): string {
            return root.dmenuSessionId
        }

        // Used by launcher/dmenu-runner.
        function dmenu(itemsPath: string, outPath: string, prompt: string, lines: int, minimalLines: bool, indexMode: bool): void {
            root.requestDmenu(itemsPath, outPath, prompt, lines, minimalLines, indexMode)
        }
    }
}
