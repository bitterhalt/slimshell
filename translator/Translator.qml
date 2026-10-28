import QtQuick
import Quickshell
import Quickshell.Io
import "../components"

Item {
    id: root

    required property var config
    required property var targetScreen
    property bool opened: false
    // Only language preferences survive closing; no text/history is retained.
    property string sourceLanguage: ""
    property string targetLanguage: "EN-GB"

    PopupMotion {
        id: popupMotion
        openDuration: root.config.popupOpenDuration
        slideDistance: root.config.popupSlideDistance
        closeDuration: root.config.popupCloseDuration
        shown: root.opened
        animationsEnabled: root.config.popupAnimations
        animationType: root.config.popupAnimationStyle
    }

    function open() { opened = true }
    function close() { opened = false }
    function toggle() { opened = !opened }

    LazyLoader {
        active: popupMotion.surfaceVisible

        TranslatorWindow {
            config: root.config
            targetScreen: root.targetScreen
            popupMotion: popupMotion
            sourceLanguage: root.sourceLanguage
            targetLanguage: root.targetLanguage
            onSourceLanguageChanged: root.sourceLanguage = sourceLanguage
            onTargetLanguageChanged: root.targetLanguage = targetLanguage
            onCloseRequested: root.close()
        }
    }

    IpcHandler {
        target: "translator"
        function open() { root.open() }
        function close() { root.close() }
        function toggle() { root.toggle() }
    }
}
