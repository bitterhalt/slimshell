import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false

    property bool disabled: false

    signal notificationRequested(string message)

    function refresh(): void {
        if (!statusCheck.running)
            statusCheck.running = true
    }

    function toggle(): void {
        if (disabled) {
            Quickshell.execDetached(["swayidle"])
            disabled = false
            notificationRequested("Enabled")
        } else {
            Quickshell.execDetached(["pkill", "-x", "swayidle"])
            disabled = true
            notificationRequested("Disabled")
        }
    }

    Process {
        id: statusCheck

        command: ["pgrep", "-x", "swayidle"]
        running: true

        onExited: exitCode => {
            root.disabled = exitCode !== 0
        }
    }

    IpcHandler {
        target: "idle"

        function toggle(): void {
            root.toggle()
        }

        function refresh(): void {
            root.refresh()
        }

        function isDisabled(): bool {
            return root.disabled
        }
    }
}
