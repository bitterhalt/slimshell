import QtQuick
import Quickshell
import Quickshell.Io
import "Scorer.js" as Scorer

Item {
    id: root
    visible: false

    required property bool active
    required property string query
    property var binaries: []
    property var history: []
    readonly property int historyShown: 5
    readonly property int historyKept: 50
    readonly property bool loading: binaryProcess.running
    readonly property var binarySet: new Set(binaries)
    readonly property var tokens: active ? splitCommand(query) : []
    readonly property string name: tokens.length > 0 ? tokens[0] : ""
    readonly property var args: tokens.slice(1)
    readonly property var recentBinaries: {
        const seen = new Set()
        const out = []
        for (let i = history.length - 1; i >= 0 && out.length < historyShown; --i) {
            const name = history[i]
            if (!name || seen.has(name))
                continue
            seen.add(name)
            if (binarySet.size > 0 && !binarySet.has(name))
                continue
            out.push(name)
        }
        return out
    }
    readonly property var results: {
        if (!active)
            return []
        const value = name.toLowerCase()
        const recent = new Set(recentBinaries)
        const toItem = (name, score) => ({type: "binary", text: name, subtitle: "",
            icon: "", recent: recent.has(name), score: score})
        if (value === "") {
            const rest = binaries.filter(name => !recent.has(name)).slice(0, 100)
                .map(name => toItem(name, 0))
            return recentBinaries.map(name => toItem(name, 0)).concat(rest)
        }
        return binaries.map(name => ({name: name, base: Scorer.scoreText(name, value)}))
            .filter(entry => entry.base > 0)
            .map(entry => toItem(entry.name, entry.base + (recent.has(entry.name) ? 200 : 0)))
            .sort((a, b) => b.score - a.score || (a.text < b.text ? -1 : 1))
    }
    signal binariesLoaded()

    onActiveChanged: {
        if (active) {
            loadBinaries()
            historyFile.reload()
        }
    }

    // First token selects the binary; quotes/backslashes preserve its arguments.
    function splitCommand(text): var {
        const tokens = []
        let current = ""
        let quote = ""
        let started = false
        let escaped = false
        for (const ch of String(text || "")) {
            if (escaped) {
                current += ch
                escaped = false
            } else if (ch === "\\" && quote !== "'") {
                escaped = true
                started = true
            } else if (quote !== "") {
                if (ch === quote)
                    quote = ""
                else
                    current += ch
            } else if (ch === "\"" || ch === "'") {
                quote = ch
                started = true
            } else if (/\s/.test(ch)) {
                if (started) {
                    tokens.push(current)
                    current = ""
                    started = false
                }
            } else {
                current += ch
                started = true
            }
        }
        if (started)
            tokens.push(current)
        return tokens
    }

    function loadBinaries(): void {
        if (binaries.length > 0 || binaryProcess.running)
            return
        const dirs = [...new Set((Quickshell.env("PATH") || "")
            .split(":").filter(dir => dir.length > 0))]
        binaryProcess.command = ["fd", "-L", "-H", "--no-ignore", "--max-depth", "1",
            "-t", "x", "-a", ".", ...dirs]
        binaryProcess.running = true
    }

    function record(name): void {
        const next = history.filter(entry => entry !== name
            && (binarySet.size === 0 || binarySet.has(entry)))
        next.push(name)
        history = next.slice(-historyKept)
        historyFile.setText(history.join("\n") + "\n")
    }

    Process {
        id: binaryProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(path => path.length > 0)
                    .map(path => path.slice(path.lastIndexOf("/") + 1))
                    .filter(name => name.length > 0)
                root.binaries = [...new Set(names)].sort()
                root.binariesLoaded()
            }
        }
        stderr: StdioCollector {}
    }

    FileView {
        id: historyFile
        path: (Quickshell.env("HOME") || "") + "/.cache/drun-history"
        atomicWrites: true
        printErrors: false
        onLoaded: root.history = text().split("\n").filter(line => line.length > 0)
    }
}
