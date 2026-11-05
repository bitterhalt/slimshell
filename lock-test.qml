import QtQuick
import Quickshell
import "lock"
import "services"

ShellRoot {
    ThemeService {
        id: lockTheme
    }
    Config {
        id: lockConfig
        theme: lockTheme
    }
    ResumeService {
        id: lockResumeService
    }
    LockContext {
        id: lockContext
        onUnlocked: Qt.quit()
    }

    FloatingWindow {
        LockSurface {
            anchors.fill: parent
            context: lockContext
            config: lockConfig
            resumeService: lockResumeService
        }
    }

    // exit the example if the window closes
    Connections {
        target: Quickshell

        function onLastWindowClosed() {
            Qt.quit();
        }
    }
}
