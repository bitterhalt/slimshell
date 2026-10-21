pragma ComponentBehavior: Bound

import "../../../components"
import "Model.js" as Model
import QtQuick
import QtQuick.Controls
import Quickshell.Networking

PopoutPanel {
    id: root

    required property var network
    property bool passwordMode: false
    property bool actionMode: false
    property string selectedSsid: ""
    property string errorText: ""
    property int selectedNetworkIndex: 0
    property int selectedActionIndex: 0
    property bool helpOpen: false
    readonly property bool showNearby: scanState.resultsVisible && network.wifiBrowsingAvailable
    readonly property var selectableRows: Model.selectableRows(network.networkRows, showNearby)

    ScanState {
        id: scanState
        wifiDevice: root.network.wifiDevice
        allowed: root.network.wifiBrowsingAvailable
    }

    function resetState() {
        const previousSsid = selectedSsid;
        passwordMode = false;
        actionMode = false;
        selectedSsid = "";
        errorText = "";
        helpOpen = false;
        selectedActionIndex = 0;
        wifiPassword.text = "";
        Qt.callLater(() => {
            const index = root.selectableRows.findIndex(row => row.ssid === previousSsid);
            root.selectNetwork(index < 0 ? root.selectedNetworkIndex : index);
            root.forceActiveFocus();
        });
    }

    function selectNetwork(index) {
        if (selectableRows.length === 0) {
            selectedSsid = "";
            selectedNetworkIndex = 0;
            return;
        }
        selectedNetworkIndex = Math.max(0, Math.min(selectableRows.length - 1, index));
        selectedSsid = selectableRows[selectedNetworkIndex].ssid;
    }

    function openSelectedNetwork() {
        const row = selectableRows.find(row => row.ssid === selectedSsid);
        if (row)
            openRow(row);
    }

    function activateAction(index) {
        selectedActionIndex = index;
        if (index === 2) {
            resetState();
            return;
        }
        const item = actionPage.selectedNetwork;
        if (!item) {
            resetState();
            return;
        }
        if (index === 0) {
            if (item.connected)
                item.disconnect();
            else
                item.connect();
        } else if (index === 1) {
            item.forget();
        }
        resetState();
    }

    function handlePopupKey(event) {
        if (!passwordMode && !actionMode && scanState.handleKey(event.key, event.modifiers)) {
            helpOpen = false;
            event.accepted = true;
            return true;
        }
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false;
        if (passwordMode) {
            if (event.key === Qt.Key_Escape) {
                resetState();
                event.accepted = true;
                return true;
            }
            return false;
        }
        if (actionMode && !helpOpen) {
            const index = Model.actionShortcut(event.text,
                !!actionPage.selectedNetwork && actionPage.selectedNetwork.connected);
            if (index >= 0) {
                activateAction(index);
                event.accepted = true;
                return true;
            }
        }
        if (event.key === Qt.Key_Escape) {
            if (helpOpen)
                helpOpen = false;
            else if (actionMode) {
                resetState();
            } else {
                network.popupManager.closeHost("network");
            }
        } else if (event.key === Qt.Key_Question || event.text === "?") {
            helpOpen = !helpOpen;
        } else if (helpOpen) {
            return false;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            if (actionMode)
                focusAction(Math.max(0, selectedActionIndex - 1));
            else
                selectNetwork(selectedNetworkIndex - 1);
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            if (actionMode)
                focusAction(Math.min(2, selectedActionIndex + 1));
            else
                selectNetwork(selectedNetworkIndex + 1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (actionMode)
                activateAction(selectedActionIndex);
            else
                openSelectedNetwork();
        } else {
            return false;
        }
        event.accepted = true;
        return true;
    }

    function focusAction(index) {
        selectedActionIndex = index;
        if (index === 0) connectAction.forceActiveFocus();
        else if (index === 1) forgetAction.forceActiveFocus();
        else cancelAction.forceActiveFocus();
    }

    function openRow(row) {
        var item = network.networkForSsid(row.ssid);
        if (!item || item.stateChanging)
            return ;

        errorText = "";
        if (item.connected || item.known) {
            selectedSsid = row.ssid;
            selectedActionIndex = 0;
            actionMode = true;
            Qt.callLater(() => connectAction.forceActiveFocus());
            return ;
        }
        if (item.security === WifiSecurityType.Open) {
            item.connect();
            return ;
        }
        selectedSsid = row.ssid;
        network.popupManager.hostFocusable = true;
        passwordMode = true;
        Qt.callLater(() => {
            return wifiPassword.forceActiveFocus();
        });
    }

    config: network.config
    focus: true
    Component.onCompleted: {
        if (selectableRows.length > 0)
            selectNetwork(0);
        Qt.callLater(() => forceActiveFocus());
    }
    Keys.onPressed: event => root.handlePopupKey(event)
    onSelectableRowsChanged: {
        if (!actionMode && !passwordMode) {
            const index = selectableRows.findIndex(row => row.ssid === selectedSsid);
            selectNetwork(index < 0 ? 0 : index);
        }
    }

    Item {
        width: parent.width
        height: root.passwordMode || root.actionMode ? 28 : 0
        visible: height > 0

        Text {
            renderType: Text.NativeRendering
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: root.config.fg
            font.pointSize: root.config.fontSize(1)
            font.weight: Font.DemiBold
            text: root.passwordMode ? "Connect to Wi-Fi" : (root.actionMode ? "Wi-Fi network" : "Network")
        }

    }

    Column {
        width: parent.width
        spacing: 2
        visible: !root.passwordMode && !root.actionMode

        Item {
            width: parent.width
            height: root.network.wiredDevice && root.network.wiredDevice.connected ? 36 : 0
            visible: height > 0

            Item {
                x: 4
                width: 28
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    color: root.config.accent
                    font.family: root.config.iconFontFamily
                    font.pointSize: root.config.iconSize
                    text: "󰈀"
                }
            }

            Column {
                x: 38
                width: parent.width - 44
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    renderType: Text.NativeRendering
                    color: root.config.fg
                    font.pointSize: root.config.fontSize(0.92)
                    font.weight: Font.DemiBold
                    text: "Ethernet"
                }

                Text {
                    renderType: Text.NativeRendering
                    color: root.config.muted
                    font.pointSize: root.config.fontSize(0.77)
                    text: root.network.wiredDevice ? root.network.wiredDevice.name : ""
                }

            }

        }

        Item {
            width: parent.width
            height: root.network.connectedWifi ? 30 : 0
            visible: height > 0

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                width: 2
                radius: 1
                color: root.config.accent
                visible: root.selectedSsid === root.network.connectedWifi?.name && !root.actionMode
            }

            Item {
                x: 4
                width: 28
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    color: root.config.accent
                    font.family: root.config.iconFontFamily
                    font.pointSize: root.config.iconSize
                    text: root.network.connectedWifi ? Model.strengthIcon(root.network.connectedWifi.signalStrength) : ""
                }
            }

            Column {
                x: 38
                width: parent.width - 44
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    renderType: Text.NativeRendering
                    width: parent.width
                    color: root.config.fg
                    font.pointSize: root.config.fontSize(0.92)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    text: root.network.connectedWifi ? root.network.connectedWifi.name : ""
                }

            }

            MouseArea {
                id: connectedWifiMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.network.connectedWifi)
                        return ;

                    root.openRow({ssid: root.network.connectedWifi.name});
                }
                onEntered: {
                    if (root.network.connectedWifi) {
                        root.selectedSsid = root.network.connectedWifi.name;
                        root.selectedNetworkIndex = root.selectableRows.findIndex(
                            row => row.ssid === root.selectedSsid);
                    }
                }
            }

        }

        Repeater {
            model: root.showNearby ? root.network.networkRows.filter((row) => {
                return !row.connected;
            }) : []

            delegate: NetworkRow {
                required property var modelData
                required property int index

                width: parent ? parent.width : 0
                height: 30
                config: root.config
                row: modelData
                enabled: !modelData.stateChanging
                selected: modelData.ssid === root.selectedSsid
                onFocused: root.selectNetwork(root.selectableRows.findIndex(
                    row => row.ssid === modelData.ssid))
                onActivated: root.openRow(modelData)
            }

        }

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: !root.network.wifiDevice
            horizontalAlignment: Text.AlignHCenter
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.85)
            text: "No Wi-Fi device found"
            topPadding: 10
            bottomPadding: 10
        }

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: !root.network.wiredConnected && root.network.wifiDevice && !Networking.wifiEnabled
            horizontalAlignment: Text.AlignHCenter
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.85)
            text: "Wi-Fi is turned off"
            topPadding: 10
            bottomPadding: 10
        }

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: root.showNearby && root.network.wifiDevice
                && root.network.networkRows.length === 0
            horizontalAlignment: Text.AlignHCenter
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.85)
            text: root.network.wifiDevice && root.network.wifiDevice.scannerEnabled ? "Scanning…" : "No networks found"
            topPadding: 10
            bottomPadding: 10
        }

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: !root.showNearby && root.network.connectionKind === "disconnected" && scanState.canScan
            horizontalAlignment: Text.AlignHCenter
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.85)
            text: "Not connected"
            topPadding: 10
            bottomPadding: 10
        }

    }

    Column {
        id: actionPage

        readonly property var selectedNetwork: root.network.networkForSsid(root.selectedSsid)

        width: parent.width
        spacing: 5
        visible: root.actionMode

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            color: root.config.fg
            font.pointSize: root.config.fontSize(0.92)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            text: root.selectedSsid
        }

        Text {
            renderType: Text.NativeRendering
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.77)
            text: parent.selectedNetwork && parent.selectedNetwork.connected ? "Connected" : "Saved network"
        }

        Button {
            id: connectAction
            KeyNavigation.tab: forgetAction
            KeyNavigation.backtab: cancelAction
            onActiveFocusChanged: if (activeFocus) root.selectedActionIndex = 0
            width: parent.width
            height: 32
            readonly property bool actionHighlighted: hovered || activeFocus
                || (root.actionMode && root.selectedActionIndex === 0)
            text: actionPage.selectedNetwork && actionPage.selectedNetwork.connected ? "Disconnect" : "Connect"
            onClicked: root.activateAction(0)

            background: Rectangle {
                radius: 4
                color: connectAction.actionHighlighted ? root.config.accent : "transparent"
                border.color: root.config.accent
                border.width: 1
            }

            contentItem: Item {
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: connectShortcut.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    color: connectAction.actionHighlighted ? root.config.bg : root.config.fg
                    font.pointSize: root.config.fontSize(0.88)
                    text: connectAction.text
                }
                Text {
                    id: connectShortcut
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    color: connectAction.actionHighlighted ? root.config.bg : root.config.muted
                    font.pointSize: root.config.fontSize(0.76)
                    text: actionPage.selectedNetwork && actionPage.selectedNetwork.connected ? "[d]" : "[c]"
                }
            }
        }

        Button {
            id: forgetAction
            KeyNavigation.tab: cancelAction
            KeyNavigation.backtab: connectAction
            onActiveFocusChanged: if (activeFocus) root.selectedActionIndex = 1
            width: parent.width
            height: 32
            readonly property bool actionHighlighted: hovered || activeFocus
                || (root.actionMode && root.selectedActionIndex === 1)
            text: "Forget"
            onClicked: root.activateAction(1)

            background: Rectangle {
                radius: 4
                color: forgetAction.actionHighlighted ? root.config.accent : "transparent"
                border.color: root.config.accent
                border.width: 1
            }

            contentItem: Item {
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: forgetShortcut.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    color: forgetAction.actionHighlighted ? root.config.bg : root.config.urgent
                    font.pointSize: root.config.fontSize(0.88)
                    text: forgetAction.text
                }
                Text {
                    id: forgetShortcut
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    color: forgetAction.actionHighlighted ? root.config.bg : root.config.muted
                    font.pointSize: root.config.fontSize(0.76)
                    text: "[f]"
                }
            }
        }

        Button {
            id: cancelAction
            KeyNavigation.tab: connectAction
            KeyNavigation.backtab: forgetAction
            onActiveFocusChanged: if (activeFocus) root.selectedActionIndex = 2
            width: parent.width
            height: 32
            readonly property bool actionHighlighted: hovered || activeFocus
                || (root.actionMode && root.selectedActionIndex === 2)
            text: "Back"
            onClicked: root.activateAction(2)

            background: Rectangle {
                radius: 3
                color: cancelAction.actionHighlighted ? root.config.accent : "transparent"
                border.color: root.config.accent
                border.width: 1
            }

            contentItem: Item {
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: backShortcut.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    color: cancelAction.actionHighlighted ? root.config.bg : root.config.fg
                    font.pointSize: root.config.fontSize(0.88)
                    text: "Back"
                }
                Text {
                    id: backShortcut
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    color: cancelAction.actionHighlighted ? root.config.bg : root.config.muted
                    font.pointSize: root.config.fontSize(0.76)
                    text: "[Esc]"
                }
            }

        }

    }

    Column {
        width: parent.width
        spacing: 8
        visible: root.passwordMode

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            color: root.config.fg
            font.pointSize: root.config.fontSize(0.92)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            text: root.selectedSsid
        }

        Text {
            renderType: Text.NativeRendering
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.77)
            text: "Enter network password"
        }

        TextField {
            renderType: Text.NativeRendering
            id: wifiPassword
            KeyNavigation.tab: cancelPassword
            KeyNavigation.backtab: connectButton

            width: parent.width
            height: 32
            focus: root.passwordMode
            onVisibleChanged: {
                if (visible)
                    Qt.callLater(() => {
                    return forceActiveFocus();
                });

            }
            echoMode: TextInput.Password
            passwordCharacter: "•"
            placeholderText: "Password"
            color: root.config.fg
            placeholderTextColor: root.config.muted
            selectionColor: root.config.accent
            selectedTextColor: root.config.fg
            font.pointSize: root.config.fontSize(0.92)
            Keys.onReturnPressed: if (connectButton.enabled) connectButton.clicked()
            Keys.onEnterPressed: if (connectButton.enabled) connectButton.clicked()

            background: Rectangle {
                color: root.config.bg
                border.color: root.config.accent
                border.width: 1
                radius: root.config.popupRadius
            }

        }

        Text {
            renderType: Text.NativeRendering
            width: parent.width
            visible: root.errorText !== ""
            color: root.config.urgent
            font.pointSize: root.config.fontSize(0.77)
            text: root.errorText
        }

        Row {
            width: parent.width
            height: 30
            spacing: 6

            Button {
                id: cancelPassword
                KeyNavigation.tab: connectButton
                KeyNavigation.backtab: wifiPassword
                width: (parent.width - 6) / 2
                height: parent.height
                text: "Cancel"
                onClicked: root.resetState()

                background: Rectangle {
                    radius: 3
                    color: cancelPassword.hovered || cancelPassword.activeFocus ? root.config.accent : "transparent"
                    border.color: root.config.accent
                    border.width: 1
                }

                contentItem: Text {
                    renderType: Text.NativeRendering
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.config.fg
                    font.pointSize: root.config.fontSize(0.85)
                    text: cancelPassword.text
                }

            }

            Button {
                id: connectButton
                KeyNavigation.tab: wifiPassword
                KeyNavigation.backtab: cancelPassword

                width: (parent.width - 6) / 2
                height: parent.height
                text: "Connect"
                enabled: root.selectedSsid !== "" && wifiPassword.text.length > 0
                onClicked: {
                    var item = root.network.networkForSsid(root.selectedSsid);
                    if (!item)
                        return ;

                    root.errorText = "";
                    item.connectWithPsk(wifiPassword.text);
                    root.passwordMode = false;
                    wifiPassword.text = "";
                    Qt.callLater(() => root.forceActiveFocus());
                }

                background: Rectangle {
                    radius: 3
                    color: root.config.accent
                }

                contentItem: Text {
                    renderType: Text.NativeRendering
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.config.fg
                    opacity: connectButton.enabled ? 1 : 0.5
                    font.pointSize: root.config.fontSize(0.85)
                    text: connectButton.text
                }

            }

        }

    }

    Text {
        renderType: Text.NativeRendering
        width: parent.width
        visible: root.helpOpen && !root.passwordMode
        color: root.config.muted
        font.pointSize: root.config.fontSize(0.74)
        wrapMode: Text.WordWrap
        text: root.actionMode
            ? (actionPage.selectedNetwork && actionPage.selectedNetwork.connected ? "d Disconnect" : "c Connect")
                + " · f Forget · Esc Back"
            : "↑/↓ or j/k Select · Enter Connect · Ctrl+S Scan/Stop · ?/Esc Help/Close"
    }

    Item {
        width: parent.width
        height: Math.max(footerStatus.implicitHeight, footerHint.implicitHeight) + root.spacing
        visible: !root.passwordMode && !root.actionMode

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.config.accent
        }

        Text {
            id: footerStatus
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: root.spacing
            renderType: Text.NativeRendering
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.78)
            text: scanState.requested ? "Scanning…" : "? Help"
        }

        Text {
            id: footerHint
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: root.spacing
            renderType: Text.NativeRendering
            color: root.config.muted
            font.pointSize: root.config.fontSize(0.78)
            text: root.network.wiredConnected ? "Ethernet connected"
                : !root.network.wifiDevice ? "No Wi-Fi adapter"
                : !Networking.wifiEnabled ? "Wi-Fi off"
                : scanState.requested ? "Ctrl+S: Stop scan" : "Ctrl+S: Scan"
        }
    }

}
