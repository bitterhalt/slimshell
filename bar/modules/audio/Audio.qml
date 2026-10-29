import "../../../components"
import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root

    required property var config
    required property var barWindow
    required property var popupManager
    required property var uiService
    required property var audioService
    readonly property var sink: audioService.sink
    readonly property var sinkAudio: audioService.sinkAudio
    readonly property int volume: audioService.volume
    readonly property bool muted: audioService.muted
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

    // Circle style's level ring is loaded only when selected in settings.json.
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

    // Left-click opens controls, right-click toggles mute, and the wheel adjusts volume.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                popupManager.toggleHost("audio", audioPopupComponent, root, true);
            else if (root.sink)
                root.audioService.toggleMute(root.sink.id);
        }
        onWheel: (wheel) => {
            if (!root.sinkAudio)
                return ;

            root.audioService.adjustVolume(root.sink.id, wheel.angleDelta.y > 0 ? 0.05 : -0.05);
        }
    }

    // Device-profile backend is loaded only when the profile tab is visited.
    Component {
        id: profileBackendComponent

        AudioProfiles {
        }

    }

    Component {
        id: audioPopupComponent

        AudioPopup {
            audioItem: root
            audioService: root.audioService
            profileBackend: profileBackendComponent
        }

    }

}
