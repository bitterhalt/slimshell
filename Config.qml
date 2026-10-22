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
    // Bar geometry
    property int barHeight: 32
    property int barEdgeMargin: 14
    property int barModuleSpacing: 8
    property int workspaceTitleGap: 10
    property bool showTray: true
    // Clock
    property string clockFormat: "HH:mm"
    property string clockAlternativeFormat: "dddd, d MMMM"
    // Desktop clock card while the bar is hidden; opacity affects its background.
    property real zenCardOpacity: 0.45
    property int zenCardMargin: 32
    // Popup geometry
    property int popupGap: 16
    property int popupRadius: 4
    // History is bounded; ordinary entries are expired before critical ones.
    property int notificationHistoryLimit: 100
    // Match desktopEntry or appName. `notify-send -a nohistory` is also supported.
    property var notificationHistoryExcludedApps: ["time-noti"]
    // Bluetooth battery percentages; 0 disables a warning. Keep critical <= low.
    property int bluetoothBatteryWarningPercent: 20
    property int bluetoothBatteryCriticalPercent: 10
    property int bluetoothBatteryRearmMargin: 5
    // Native idle defaults, in seconds. Menu overrides are saved separately.
    property int idleLockTimeout: 1200
    property int idleOffTimeout: 1800
    property int idleSuspendTimeout: 7200
    // Semantic palette supplied by ThemeService.
    // ThemeService falls back to the hardcoded palette when Pywal is absent.
    readonly property color bg: theme.bg
    readonly property color surface: theme.surface
    readonly property color fg: theme.fg
    readonly property color muted: theme.muted
    readonly property color accent: theme.accent
    readonly property color urgent: theme.urgent
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
