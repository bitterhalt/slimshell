import "../../../components"
import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    required property var config
    required property var row
    required property var node
    property bool selected: false
    readonly property var nodeAudio: node && node.audio ? node.audio : null

    signal picked()
    signal optionsRequested()
    signal muteRequested()
    signal volumeRequested(real value)

    objectName: "audioVolumeRow"
    implicitHeight: root.row.kind === "playback" ? 56 : 44

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        width: 3
        radius: 1
        color: root.config.selectionBackground
        visible: root.selected
    }

    HoverHandler {
        id: rowHover
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            root.picked();
            if (mouse.button === Qt.RightButton && root.nodeAudio)
                root.muteRequested();

        }
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                root.optionsRequested();

        }
    }

    // Name and secondary device/media status.
    Text {
        objectName: "audioVolumeName"
        renderType: Text.NativeRendering
        anchors.left: slider.left
        anchors.leftMargin: slider.leftPadding
        anchors.right: defaultLabel.visible ? defaultLabel.left : slider.right
        anchors.rightMargin: defaultLabel.visible ? 8 : slider.rightPadding
        y: 2
        color: rowHover.hovered ? Qt.lighter(root.config.fg, 1.15) : root.config.fg
        font.pointSize: root.config.fontSize(0.9)
        font.weight: root.selected ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
        text: root.row.name
    }

    Text {
        id: defaultLabel

        renderType: Text.NativeRendering
        anchors.right: slider.right
        anchors.rightMargin: slider.rightPadding
        y: 3
        visible: !!root.row.active || !!(root.nodeAudio && root.nodeAudio.muted)
        text: root.nodeAudio && root.nodeAudio.muted ? (root.row.active ? "Muted · Default" : "Muted") : "Default"
        color: root.nodeAudio && root.nodeAudio.muted ? root.config.muted : root.config.selectionBackground
        font.pointSize: root.config.fontSize(0.72)
    }

    Text {
        renderType: Text.NativeRendering
        anchors.left: slider.left
        anchors.leftMargin: slider.leftPadding
        anchors.right: slider.right
        anchors.rightMargin: slider.rightPadding
        y: 20
        color: root.config.muted
        font.pointSize: root.config.fontSize(0.75)
        elide: Text.ElideRight
        text: root.row.media || ""
        visible: root.row.kind === "playback" && text !== ""
    }

    // Keep Slider's mouse/keyboard behavior, with a segmented track and no thumb.
    Slider {
        id: slider

        objectName: "audioVolumeSlider"
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        height: 18
        padding: 4
        from: 0
        to: Math.max(0, root.config.maxVolume)
        stepSize: 0.01
        focusPolicy: Qt.NoFocus
        enabled: root.nodeAudio !== null
        opacity: root.nodeAudio && root.nodeAudio.muted ? 0.4 : 1
        value: root.nodeAudio ? root.nodeAudio.volume : 0
        onPressedChanged: {
            if (pressed)
                root.picked();

        }
        onMoved: root.volumeRequested(value)

        background: VolumeMeter {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 14
            config: root.config
            value: slider.value
            maximum: slider.to
            segmentCount: Math.max(1, Math.floor((width + spacing) / (4 + spacing)))
        }

        handle: Item {
            width: 0
            height: 0
        }

    }

}
