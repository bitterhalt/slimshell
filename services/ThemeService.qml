import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    readonly property color fallbackBg: "#100f0f"
    readonly property color fallbackFg: "#cecdc3"
    readonly property color fallbackMuted: Qt.alpha(fallbackFg, 0.85)
    readonly property color fallbackSelectionBackground: "#205ea6"
    readonly property color fallbackUrgent: "#bc5215"
    readonly property color fallbackSelectionForeground: "#ffffff"

    property color bg: fallbackBg
    property color fg: fallbackFg
    property color muted: fallbackMuted
    property color urgent: fallbackUrgent
    property color selectionBackground: fallbackSelectionBackground
    property color selectionForeground: fallbackSelectionForeground
    readonly property color border: Qt.alpha(selectionBackground, 0.45)

    property bool hellwalActive: false

    function applyFallback(): void {
        bg = fallbackBg
        fg = fallbackFg
        muted = fallbackMuted
        urgent = fallbackUrgent
        selectionBackground = fallbackSelectionBackground
        selectionForeground = fallbackSelectionForeground
        hellwalActive = false
    }

    function parsePalette(text): var {
        const colors = {}
        let match

        let re = /@define-color\s+(background|foreground|selection_background|selection_foreground|color(?:1[0-5]|[0-9]))\s+(#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)/g
        while ((match = re.exec(text)) !== null)
            colors[match[1]] = match[2]

        re = /--(background|foreground|selection_background|selection_foreground|color(?:1[0-5]|[0-9]))\s*:\s*(#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)/g
        while ((match = re.exec(text)) !== null)
            colors[match[1]] = match[2]

        re = /\$(background|foreground|selection_background|selection_foreground|color(?:1[0-5]|[0-9]))\s*:\s*(#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)/g
        while ((match = re.exec(text)) !== null)
            colors[match[1]] = match[2]

        const required = [
            "background",
            "foreground",
            "color3",
            "color6",
        ]

        for (let i = 0; i < required.length; ++i) {
            if (!colors[required[i]])
                return null
        }

        return colors
    }

    function applyPalette(text): void {
        const colors = parsePalette(text)

        if (!colors) {
            applyFallback()
            return
        }

        bg = colors.background
        fg = colors.foreground
        muted = Qt.alpha(fg, 0.65)
        urgent = colors.color3
        selectionBackground = colors.color6
        selectionForeground =  bg
        hellwalActive = true
    }

    function refresh(): void {
        paletteFile.reload()
    }

    FileView {
        id: paletteFile

        path: Quickshell.env("HOME") + "/.cache/hellwal/colors.css"
        watchChanges: true
        printErrors: false

        onLoaded: root.applyPalette(text())
        onFileChanged: reload()
        onLoadFailed: root.applyFallback()
    }

    IpcHandler {
        target: "theme"

        function refresh(): void {
            root.refresh()
        }

        function usingHellwal(): bool {
            return root.hellwalActive
        }
    }
}
