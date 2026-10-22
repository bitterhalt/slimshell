import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

Scope {
    id: root

    required property var config
    required property var targetScreen

    readonly property var flow: agent.flow

    function clearResponse(): void {
        responseField.text = ""
    }

    function focusPrompt(): void {
        if (flow && flow.isResponseRequired)
            responseField.forceActiveFocus()
        else
            cancelButton.forceActiveFocus()
    }

    function submitResponse(): void {
        if (!flow || !flow.isResponseRequired)
            return

        const response = responseField.text
        responseField.text = ""
        flow.submit(response)
    }

    function cancelRequest(): void {
        if (flow)
            flow.cancelAuthenticationRequest()
        clearResponse()
    }

    PolkitAgent {
        id: agent
    }

    PanelWindow {
        id: promptWindow

        screen: root.targetScreen
        visible: agent.isActive
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        implicitWidth: 390
        implicitHeight: promptCard.implicitHeight

        anchors {
            top: true
            left: true
        }

        margins.top: screen
            ? Math.max(0, Math.round((screen.height - implicitHeight) / 2))
            : 0
        margins.left: screen
            ? Math.max(0, Math.round((screen.width - implicitWidth) / 2))
            : 0

        WlrLayershell.namespace: "slim-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => root.focusPrompt())
            else
                root.clearResponse()
        }


        Rectangle {
            id: promptCard

            anchors.fill: parent
            color: root.config.surface
            border.color: root.config.accent
            border.width: 1
            radius: root.config.popupRadius
            implicitHeight: content.implicitHeight + 32

             // Re-focus once the compositor actually gives the window keyboard focus
            Window.onActiveChanged: {
                if (Window.active)
                    root.focusPrompt()
            }

            Column {
                id: content

                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    renderType: Text.NativeRendering
                    width: parent.width
                    color: root.config.fg
                    font.pointSize: root.config.fontSize(1.05)
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    text: root.flow ? root.flow.message : "Authentication required"
                }

                Text {
                    renderType: Text.NativeRendering
                    width: parent.width
                    visible: !!root.flow && root.flow.actionId !== ""
                    color: root.config.muted
                    font.pointSize: root.config.fontSize(0.78)
                    wrapMode: Text.WordWrap
                    text: root.flow ? root.flow.actionId : ""
                }

                Text {
                    renderType: Text.NativeRendering
                    width: parent.width
                    visible: !!root.flow && root.flow.identities.length > 1
                    color: root.config.fg
                    font.pointSize: root.config.fontSize(0.86)
                    text: "Authenticate as"
                }

                ComboBox {
                    id: identityPicker

                    width: parent.width
                    visible: !!root.flow && root.flow.identities.length > 1
                    model: root.flow ? root.flow.identities : []
                    textRole: "displayName"
                    currentIndex: root.flow
                        ? root.flow.identities.indexOf(root.flow.selectedIdentity) : -1
                    onActivated: index => {
                        if (root.flow && index >= 0) {
                            root.clearResponse()
                            root.flow.selectedIdentity = root.flow.identities[index]
                            Qt.callLater(() => root.focusPrompt())
                        }
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    width: parent.width
                    visible: !!root.flow && root.flow.identities.length === 1
                    color: root.config.muted
                    font.pointSize: root.config.fontSize(0.86)
                    text: root.flow && root.flow.selectedIdentity
                        ? root.flow.selectedIdentity.displayName : ""
                }

                Text {
                    renderType: Text.NativeRendering
                    width: parent.width
                    visible: !!root.flow && root.flow.supplementaryMessage !== ""
                    color: root.flow && root.flow.supplementaryIsError
                        ? root.config.urgent : root.config.muted
                    font.pointSize: root.config.fontSize(0.82)
                    wrapMode: Text.WordWrap
                    text: root.flow ? root.flow.supplementaryMessage : ""
                }

                TextField {
                    id: responseField

                    width: parent.width
                    visible: !!root.flow && root.flow.isResponseRequired
                    placeholderText: root.flow ? root.flow.inputPrompt : ""
                    color: root.config.fg
                    selectionColor: root.config.accent
                    selectedTextColor: root.config.bg
                    font.pointSize: root.config.fontSize(0.9)
                    echoMode: root.flow && root.flow.responseVisible
                        ? TextInput.Normal : TextInput.Password
                    selectByMouse: true
                    activeFocusOnTab: true
                    onAccepted: root.submitResponse()

                    // Grab focus as soon as the field actually appears
                    onVisibleChanged: {
                        if (visible)
                            Qt.callLater(() => forceActiveFocus())
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.cancelRequest()
                            event.accepted = true
                        }
                    }

                    background: Rectangle {
                        color: root.config.bg
                        radius: 4
                        border.width: 1
                        border.color: responseField.activeFocus
                            ? root.config.accent : root.config.muted
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8
                    layoutDirection: Qt.RightToLeft

                    Button {
                        id: cancelButton

                        text: "Cancel"
                        height: 28
                        font.pointSize: root.config.fontSize(0.88)
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: 4
                        bottomPadding: 4
                        onClicked: root.cancelRequest()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                root.cancelRequest()
                                event.accepted = true
                            }
                        }
                    }

                    Button {
                        visible: !!root.flow && root.flow.isResponseRequired
                        text: "Authenticate"
                        highlighted: true
                        height: 28
                        font.pointSize: root.config.fontSize(0.88)
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: 4
                        bottomPadding: 4
                        onClicked: root.submitResponse()
                    }
                }
            }
        }

        Connections {
            target: agent

            function onFlowChanged(): void {
                root.clearResponse()
                if (agent.isActive)
                    Qt.callLater(() => root.focusPrompt())
            }
        }

        // Refocus when PAM actually asks for input (often after the window is shown)
        Connections {
            target: root.flow
            ignoreUnknownSignals: true

            function onIsResponseRequiredChanged(): void {
                if (root.flow && root.flow.isResponseRequired)
                    Qt.callLater(() => root.focusPrompt())
            }
        }
    }
}
