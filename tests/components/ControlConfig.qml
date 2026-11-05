import QtQuick

QtObject {
    property color bg: "#101010"
    property color fg: "#eeeeee"
    property color muted: "#888888"
    property color urgent: "#dd4444"
    property color border: "#444444"
    property color selectionBackground: "#6699cc"
    property color selectionForeground: "#ffffff"
    property int popupRadius: 4
    property int popupGap: 16
    property bool popupAnimations: false
    property int spacingTight: 4
    property int spacingControl: 8
    property int panelPadding: 12
    property int previewPadding: 16
    property string textFontFamily: "sans-serif"
    property string iconFontFamily: "sans-serif"
    property real iconSize: 10

    readonly property real fontSize: 10
    readonly property real textSizeNormal: fontSize
    readonly property real textSizeMedium: fontSize * 0.88
    readonly property real textSizeSmall: fontSize * 0.76
}
