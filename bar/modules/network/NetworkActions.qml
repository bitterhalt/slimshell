import QtQuick
import "../../../components"

Column {
    id: root

    required property var config
    required property string ssid
    required property var selectedNetwork
    property int selectedIndex: 0

    signal activated(int index)
    signal focused(int index)

    function focusAction(index): void {
        if (index === 0)
            connectAction.forceActiveFocus();
        else if (index === 1)
            forgetAction.forceActiveFocus();
        else
            cancelAction.forceActiveFocus();
    }

    spacing: 5

    Text {
        renderType: Text.NativeRendering
        width: parent.width
        color: root.config.fg
        font.pointSize: root.config.fontSize * 0.92
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        text: root.ssid
    }

    Text {
        renderType: Text.NativeRendering
        color: root.config.muted
        font.pointSize: root.config.fontSize * 0.77
        text: root.selectedNetwork && root.selectedNetwork.connected ? "Connected" : "Saved network"
    }

    ActionRow {
        id: connectAction
        objectName: "networkConnectAction"
        config: root.config
        selected: root.visible && root.selectedIndex === 0
        shortcutText: root.selectedNetwork && root.selectedNetwork.connected ? "[d]" : "[c]"
        KeyNavigation.tab: forgetAction
        KeyNavigation.backtab: cancelAction
        onActiveFocusChanged: if (activeFocus)
            root.focused(0)
        width: parent.width
        height: 32
        text: root.selectedNetwork && root.selectedNetwork.connected ? "Disconnect" : "Connect"
        onClicked: root.activated(0)
    }

    ActionRow {
        id: forgetAction
        objectName: "networkForgetAction"
        config: root.config
        selected: root.visible && root.selectedIndex === 1
        destructive: true
        shortcutText: "[f]"
        KeyNavigation.tab: cancelAction
        KeyNavigation.backtab: connectAction
        onActiveFocusChanged: if (activeFocus)
            root.focused(1)
        width: parent.width
        height: 32
        text: "Forget"
        onClicked: root.activated(1)
    }

    ActionRow {
        id: cancelAction
        objectName: "networkBackAction"
        config: root.config
        selected: root.visible && root.selectedIndex === 2
        shortcutText: "[Esc]"
        cornerRadius: 3
        KeyNavigation.tab: connectAction
        KeyNavigation.backtab: forgetAction
        onActiveFocusChanged: if (activeFocus)
            root.focused(2)
        width: parent.width
        height: 32
        text: "Back"
        onClicked: root.activated(2)
    }
}
