import QtQuick
import Quickshell
import Quickshell.Widgets
import "Dmenu.js" as Dmenu

// Rendering only. The launcher owns selection, activation and the timer clock.
Item {
    id: root

    required property var config
    required property var entry
    property bool selected: false
    property string remainingText: ""
    readonly property string iconRun: String.fromCodePoint(0xF018D)
    readonly property string iconStar: String.fromCodePoint(0xF04CE)

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.selected ? root.config.selectionBackground : "transparent"
    }

    IconImage {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 26
        visible: source.toString() !== ""
        source: root.entry.icon ? Quickshell.iconPath(root.entry.icon, true) : ""
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: root.entry.type === "calculator" || root.entry.type === "file" || root.entry.type === "binary" || root.entry.type === "emoji" || root.entry.type === "timer-start" || root.entry.type === "timer-active"
        color: root.selected ? root.config.selectionForeground : root.config.selectionBackground
        font.family: root.entry.type === "emoji" ? root.config.textFontFamily : root.config.iconFontFamily
        font.pointSize: root.config.iconSize * 1.5
        text: root.entry.type === "emoji" ? root.entry.emoji : root.entry.type === "file" ? "󰈔" : root.entry.type === "binary" ? (root.entry.recent ? root.iconStar : root.iconRun) : root.entry.type === "timer-start" || root.entry.type === "timer-active" ? "󰔛" : "󰃬"
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: root.entry.type === "dmenu" ? 12 : 50
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            objectName: "launcherResultTitle"
            renderType: Text.NativeRendering
            width: parent.width
            color: root.selected ? root.config.selectionForeground : root.config.fg
            font.pointSize: root.config.textSizeMedium
            font.family: root.config.textFontFamily
            font.weight: Font.Medium
            elide: Text.ElideRight
            textFormat: root.entry.type === "dmenu" ? Text.RichText : Text.AutoText
            text: root.entry.type === "dmenu" ? Dmenu.richTextWithSymbols(root.entry.text, root.config.iconFontFamily) : root.entry.text
        }

        Text {
            objectName: "launcherResultSubtitle"
            renderType: Text.NativeRendering
            width: parent.width
            visible: root.entry.type === "timer-active" || (root.entry.subtitle || "") !== ""
            color: root.selected ? root.config.selectionForeground : root.config.muted
            font.pointSize: root.config.textSizeSmall
            elide: Text.ElideRight
            text: root.entry.type === "timer-active" ? root.remainingText : root.entry.subtitle || ""
        }
    }
}
