import QtQuick
import Quickshell
import Quickshell.Io
import "config/Schema.js" as Schema

Item {
    id: config

    required property var theme
    property var values: Schema.defaults()
    property bool ready: false
    property bool applying: false

    readonly property real fontScale: values.fontScale
    readonly property real iconScale: values.iconScale
    readonly property string iconFontFamily: values.iconFontFamily
    readonly property real maxVolume: values.maxVolume
    readonly property string audioStyle: values.audioStyle
    readonly property int barHeight: values.barHeight
    readonly property bool showTray: values.showTray
    readonly property bool launcherEnabled: values.launcherEnabled
    readonly property string clockFormat: values.clockFormat
    readonly property string clockAlternativeFormat: values.clockAlternativeFormat
    readonly property int popupGap: values.popupGap
    readonly property int popupRadius: values.popupRadius
    readonly property bool popupAnimations: values.popupAnimations
    readonly property int popupOpenDuration: values.popupOpenDuration
    readonly property real popupSlideDistance: values.popupSlideDistance
    readonly property int popupCloseDuration: values.popupCloseDuration
    readonly property string popupAnimationStyle: values.popupAnimationStyle
    readonly property var popupAnimationTypes: values.popupAnimationTypes
    readonly property string notificationAnimationStyle: values.notificationAnimationStyle
    readonly property int notificationHistoryLimit: values.notificationHistoryLimit
    readonly property var notificationHistoryExcludedApps: values.notificationHistoryExcludedApps
    readonly property int bluetoothBatteryWarningPercent: values.bluetoothBatteryWarningPercent
    readonly property int bluetoothBatteryCriticalPercent: values.bluetoothBatteryCriticalPercent
    readonly property int bluetoothBatteryRearmMargin: values.bluetoothBatteryRearmMargin
    // Semantic palette supplied by ThemeService, with its own fallback palette.
    readonly property color bg: theme.bg
    readonly property color fg: theme.fg
    readonly property color muted: theme.muted
    readonly property color urgent: theme.urgent
    readonly property color selectionBackground: theme.selectionBackground
    readonly property color selectionForeground: theme.selectionForeground
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

    function applySettings(text) {
        try {
            const parsed = Schema.parse(text)
            applying = true
            values = parsed.values
            if (parsed.warnings.length > 0)
                console.warn("settings.json: using defaults for " + parsed.warnings.join(", "))
        } catch (error) {
            console.warn("Invalid settings.json; keeping previous settings")
        }
        applying = false
        ready = true
    }

    Component.onCompleted: {
        const initial = settingsFile.text()
        if (!ready)
            applySettings(initial)
    }

    FileView {
        id: settingsFile
        path: Qt.resolvedUrl("../settings.json").toString()
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: config.applySettings(text())
        onLoadFailed: {
            config.ready = true
            console.warn("Could not load settings.json; keeping current settings")
        }
    }

    FontMetrics {
        id: systemFontMetrics
    }

}
