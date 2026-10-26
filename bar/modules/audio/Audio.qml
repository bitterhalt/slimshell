import "../../../components"
import "Model.js" as Model
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    required property var config
    required property var barWindow
    required property var popupManager
    required property var uiService
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source ? source.audio : null
    readonly property var allNodes: Pipewire.nodes ? Pipewire.nodes.values : []
    // Bind all audio nodes that we expose controls for. PwNodeAudio's
    // writable volume/mute properties require the node to be tracked.
    readonly property var trackedNodes: allNodes.filter((node) => {
        return node && node.audio;
    })
    readonly property var outputRows: Model.deviceRows(allNodes, true, sink ? sink.id : -1)
    readonly property var inputRows: Model.deviceRows(allNodes, false, source ? source.id : -1)
    readonly property var streamRows: Model.playbackStreams(allNodes)
    readonly property int volume: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
    readonly property bool muted: sinkAudio ? sinkAudio.muted : false
    readonly property bool circleStyle: config.audioStyle === "circle"
    readonly property real volumeLevel: sinkAudio && config.maxVolume > 0 ? Math.max(0, Math.min(sinkAudio.volume / config.maxVolume, 1)) : 0
    readonly property string icon: {
        if (muted)
            return "󰝟";

        if (circleStyle)
            return "󰕾";

        if (volume < 25)
            return "󰕿";

        if (volume < 60)
            return "󰖀";

        return "󰕾";
    }

    function nodeForId(id) {
        for (var i = 0; i < allNodes.length; ++i) {
            var node = allNodes[i];
            if (node && Number(node.id) === Number(id))
                return node;

        }
        return null;
    }

    function setOutput(id) {
        var node = nodeForId(id);
        if (!node || !node.audio || node.isStream || !node.isSink)
            return ;

        Pipewire.preferredDefaultAudioSink = node;
    }

    function setInput(id) {
        var node = nodeForId(id);
        if (!node || !node.audio || node.isStream || node.isSink)
            return ;

        Pipewire.preferredDefaultAudioSource = node;
    }

    function setVolume(id, value) {
        const node = nodeForId(id);
        if (!node || !node.audio || !Number.isFinite(value))
            return ;

        node.audio.volume = Model.clampVolume(value, root.config.maxVolume);
    }

    function adjustVolume(id, delta) {
        const node = nodeForId(id);
        if (node && node.audio)
            setVolume(id, node.audio.volume + delta);

    }

    function toggleMute(id) {
        const node = nodeForId(id);
        if (!node || !node.audio)
            return ;

        node.audio.muted = !node.audio.muted;
    }

    function closePopup() {
        popupManager.closeHost("audio");
    }

    width: 24
    height: barWindow.height

    Connections {
        function onAudioActionRequested(action) {
            if (action === "close" || root.barWindow.screen !== root.uiService.targetScreen) {
                root.closePopup();
                return ;
            }
            if (action === "open")
                root.popupManager.openHost("audio", audioPopupComponent, root, true);
            else if (action === "toggle")
                root.popupManager.toggleHost("audio", audioPopupComponent, root, true);
        }

        target: root.uiService
    }

    PwObjectTracker {
        objects: root.trackedNodes
    }

    Loader {
        anchors.centerIn: parent
        width: 24
        height: 24
        active: root.circleStyle

        sourceComponent: Component {
            Canvas {
                id: volumeRing
                anchors.fill: parent

                onPaint: {
                    const context = getContext("2d");
                    const center = width / 2;
                    const radius = center - 1.5;
                    const start = -Math.PI / 2;
                    context.clearRect(0, 0, width, height);
                    context.beginPath();
                    context.arc(center, center, radius, 0, Math.PI * 2, false);
                    context.lineWidth = 2;
                    context.lineCap = "round";
                    context.globalAlpha = 0.35;
                    context.strokeStyle = root.config.muted.toString();
                    context.stroke();
                    if (root.volumeLevel > 0) {
                        context.beginPath();
                        context.arc(center, center, radius, start,
                            start + Math.PI * 2 * root.volumeLevel, false);
                        context.globalAlpha = 1;
                        context.strokeStyle = root.config.selectionBackground.toString();
                        context.stroke();
                    }
                    context.globalAlpha = 1;
                }

                Connections {
                    function onVolumeLevelChanged() {
                        volumeRing.requestPaint();
                    }

                    target: root
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        color: root.circleStyle && root.muted ? config.muted : config.fg
        opacity: root.circleStyle || !root.muted ? 1 : 0.5
        font.family: config.iconFontFamily
        font.pointSize: root.circleStyle ? config.iconSize * 0.82 : config.iconSize
        text: root.icon
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                popupManager.toggleHost("audio", audioPopupComponent, root, true);
            else if (root.sinkAudio)
                root.sinkAudio.muted = !root.sinkAudio.muted;
        }
        onWheel: (wheel) => {
            if (!root.sinkAudio)
                return ;

            var next = root.sinkAudio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05);
            root.sinkAudio.volume = Model.clampVolume(next, root.config.maxVolume);
        }
    }

    Component {
        id: profileBackendComponent

        AudioProfiles {
        }

    }

    Component {
        id: audioPopupComponent

        AudioPopup {
            audioItem: root
            profileBackend: profileBackendComponent
        }

    }

}
