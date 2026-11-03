import QtQuick

// Inert surface for feature UI tests; the real tooltip is tested separately.
QtObject {
    required property var config
    required property Item anchorItem
    property string text: ""
    property bool shown: false
    property int delay: 400
}
