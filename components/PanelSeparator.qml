import QtQuick

// One-pixel themed divider for popup sections.
Rectangle {
    required property var config

    width: parent ? parent.width : 0
    implicitHeight: 1
    color: config.selectionBackground
}
