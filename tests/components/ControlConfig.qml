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
    property string textFontFamily: "sans-serif"
    property string iconFontFamily: "sans-serif"
    property real iconSize: 10

    function fontSize(scale) {
        return 10 * scale;
    }
}
