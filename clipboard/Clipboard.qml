pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var config
    required property var targetScreen

    readonly property ClipboardPanel panel: panelLoader.active
        ? panelLoader.item as ClipboardPanel : null
    readonly property bool opened: panel ? panel.opened : false

    function open(): void {
        // Construct synchronously on first use, then retain for fast reuse.
        panelLoader.active = true
        panel.open()
    }

    function toggle(): void {
        opened ? close() : open()
    }

    function close(): void {
        if (panel)
            panel.close()
    }

    function refresh(): void {
        if (panel)
            panel.refresh()
    }

    function copySelected(): void {
        if (panel)
            panel.copySelected()
    }

    function deleteSelected(): void {
        if (panel)
            panel.deleteSelected()
    }

    LazyLoader {
        id: panelLoader
        active: false

        ClipboardPanel {
            config: root.config
            targetScreen: root.targetScreen
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
        function refresh(): void { root.refresh() }
        function copySelected(): void { root.copySelected() }
        function deleteSelected(): void { root.deleteSelected() }
    }
}
