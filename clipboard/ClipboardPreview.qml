import QtQuick

// Inert view: the panel owns fetching/decoding and supplies the preview data.
Item {
    id: root

    required property var config
    required property var entry
    property bool ready: false
    property string imagePath: ""
    property string previewText: ""
    property bool historyEmpty: true

    Image {
        anchors.fill: parent
        anchors.margins: 16
        visible: root.ready && root.entry && root.entry.isImage
        source: root.ready ? "file://" + root.imagePath : ""
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
        asynchronous: true
        cache: false
    }

    Text {
        objectName: "clipboardPreviewText"
        renderType: Text.NativeRendering
        anchors.fill: parent
        anchors.margins: 18
        visible: root.entry && !root.entry.isImage
        color: root.config.fg
        font.family: "monospace"
        font.pointSize: root.config.fontSize * 0.82
        wrapMode: Text.WrapAnywhere
        text: root.previewText
        clip: true
    }

    Text {
        objectName: "clipboardPreviewEmpty"
        renderType: Text.NativeRendering
        anchors.centerIn: parent
        visible: !root.entry
        color: root.config.muted
        font.pointSize: root.config.fontSize * 0.9
        text: root.historyEmpty ? "Clipboard history is empty" : "Select an item to preview"
    }
}
