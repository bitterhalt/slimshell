import QtQuick
import Quickshell

Item {
    id: config

    required property var theme
    // Typography
    property real fontScale: 1
    property real iconScale: 1
    property string iconFontFamily: "Symbols Nerd Font Mono"
    // Audio control ceiling: 1.0 = 100%, 1.1 = 110%.
    property real maxVolume: 1.1
    property string audioStyle: "classic" // "classic" or "circle"
    // Bar geometry
    property int barHeight: 32
    property bool showTray: true
    // Disable the built-in launcher when using a third-party launcher.
    property bool launcherEnabled: true
    // Clock
    property string clockFormat: "HH:mm"
    property string clockAlternativeFormat: "dddd, d MMMM"
    // Desktop clock card while the bar is hidden; opacity affects its background.
    // Popup geometry
    property int popupGap: 16
    property int popupRadius: 4
    // History is bounded; ordinary entries are expired before critical ones.
    property int notificationHistoryLimit: 100
    // Match desktopEntry or appName. `notify-send -a nohistory` is also supported.
    property var notificationHistoryExcludedApps: ["time-noti", "niri", "thunar", "Media-notify", "wl-color-picker"]
    // Bluetooth battery percentages; 0 disables a warning. Keep critical <= low.
    property int bluetoothBatteryWarningPercent: 20
    property int bluetoothBatteryCriticalPercent: 10
    property int bluetoothBatteryRearmMargin: 5
    // Native idle defaults, in seconds. Menu overrides are saved separately.
    property int idleLockTimeout: 1200
    property int idleOffTimeout: 1800
    property int idleSuspendTimeout: 7200
    // Semantic palette supplied by ThemeService, with its own fallback palette.
    readonly property color bg: theme.bg
    readonly property color fg: theme.fg
    readonly property color muted: theme.muted
    readonly property color urgent: theme.urgent
    readonly property color selectionBackground: theme.selectionBackground
    readonly property color selectionForeground: theme.selectionForeground
    readonly property color cursorText: theme.cursorText
    readonly property string textFontFamily: systemFontMetrics.font.family
    readonly property real systemFontPointSize: systemFontMetrics.font.pointSize > 0 ? systemFontMetrics.font.pointSize : 10
    readonly property real iconSize: systemFontPointSize * fontScale * iconScale

    function fontSize(scale) {
        return systemFontPointSize * fontScale * scale;
    }

    function run(command) {
        Quickshell.execDetached(["sh", "-lc", command]);
    }

    visible: false

    FontMetrics {
        id: systemFontMetrics
    }

}
