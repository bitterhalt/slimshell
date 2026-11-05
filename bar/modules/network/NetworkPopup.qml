pragma ComponentBehavior: Bound

import "../../../components"
import "Model.js" as Model
import QtQuick
import Quickshell.Networking

PopoutPanel {
    id: root

    required property var network
    required property var popupManager
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
            const index = Model.actionShortcut(event.text, !!actionPage.selectedNetwork && actionPage.selectedNetwork.connected);
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
                popupManager.closeHost("network");
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
        actionPage.focusAction(index);
    }

    function openRow(row) {
        var item = network.networkForSsid(row.ssid);
        if (!item || item.stateChanging)
            return;

        errorText = "";
        if (item.connected || item.known) {
            selectedSsid = row.ssid;
            selectedActionIndex = 0;
            actionMode = true;
            Qt.callLater(() => actionPage.focusAction(0));
            return;
        }
        if (item.security === WifiSecurityType.Open) {
            item.connect();
            return;
        }
        selectedSsid = row.ssid;
        popupManager.hostFocusable = true;
        passwordMode = true;
        Qt.callLater(() => {
            return wifiPassword.focusInput();
        });
    }

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

    // Page title shown for connect/password/action subpages.
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

    // Connected Ethernet/Wi-Fi and nearby access points.
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
                    color: root.config.selectionBackground
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

        NetworkRow {
            width: parent.width
            height: root.network.connectedWifi ? 40 : 0
            visible: height > 0
            config: root.config
            row: root.network.connectedWifi ? ({
                    ssid: root.network.connectedWifi.name,
                    strength: root.network.connectedWifi.signalStrength,
                    connected: true,
                    known: true
                }) : ({
                    ssid: "",
                    strength: 0,
                    connected: true
                })
            secured: root.network.connectedWifi ? root.network.connectedWifi.security !== WifiSecurityType.Open : true
            selected: root.network.connectedWifi !== null && root.selectedSsid === root.network.connectedWifi.name
            onFocused: {
                if (root.network.connectedWifi) {
                    root.selectedSsid = root.network.connectedWifi.name;
                    root.selectedNetworkIndex = root.selectableRows.findIndex(row => row.ssid === root.selectedSsid);
                }
            }
            onActivated: {
                if (root.network.connectedWifi)
                    root.openRow({
                        ssid: root.network.connectedWifi.name
                    });
            }
        }

        Repeater {
            model: root.showNearby ? root.network.networkRows.filter(row => {
                return !row.connected;
            }) : []

            delegate: NetworkRow {
                required property var modelData
                required property int index

                width: parent ? parent.width : 0
                height: 40
                config: root.config
                row: modelData
                secured: modelData.security !== WifiSecurityType.Open
                enabled: !modelData.stateChanging
                selected: modelData.ssid === root.selectedSsid
                onFocused: root.selectNetwork(root.selectableRows.findIndex(row => row.ssid === modelData.ssid))
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
            visible: root.showNearby && root.network.wifiDevice && root.network.networkRows.length === 0
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

    // Connect, forget, and back actions for a selected network.
    NetworkActions {
        id: actionPage

        config: root.config
        ssid: root.selectedSsid
        selectedNetwork: root.network.networkForSsid(root.selectedSsid)
        selectedIndex: root.selectedActionIndex
        onFocused: index => root.selectedActionIndex = index
        onActivated: index => root.activateAction(index)
        width: parent.width
        visible: root.actionMode
    }

    // Password entry and connection feedback.
    NetworkPasswordForm {
        id: wifiPassword
        config: root.config
        ssid: root.selectedSsid
        errorText: root.errorText
        width: parent.width
        visible: root.passwordMode
        onCancelled: root.resetState()
        onSubmitted: password => {
            const item = root.network.networkForSsid(root.selectedSsid);
            if (!item)
                return;
            root.errorText = "";
            item.connectWithPsk(password);
            root.passwordMode = false;
            wifiPassword.text = "";
            Qt.callLater(() => root.forceActiveFocus());
        }
    }

    // Keyboard help for the scan and popup shortcuts.
    Text {
        renderType: Text.NativeRendering
        width: parent.width
        visible: root.helpOpen && !root.passwordMode
        color: root.config.muted
        font.pointSize: root.config.fontSize(0.74)
        wrapMode: Text.WordWrap
        text: root.actionMode ? (actionPage.selectedNetwork && actionPage.selectedNetwork.connected ? "d Disconnect" : "c Connect") + " · f Forget · Esc Back" : "↑/↓ or j/k Select · Enter Connect · Ctrl+S Scan/Stop · ?/Esc Help/Close"
    }

    // Bottom connection status and scan controls.
    Item {
        width: parent.width
        height: Math.max(footerStatus.implicitHeight, footerHint.implicitHeight) + root.spacing
        visible: !root.passwordMode && !root.actionMode

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.config.border
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
            text: root.network.wiredConnected ? "Ethernet connected" : !root.network.wifiDevice ? "No Wi-Fi adapter" : !Networking.wifiEnabled ? "Wi-Fi off" : scanState.requested ? "Ctrl+S: Stop scan" : "Ctrl+S: Scan"
        }
    }
}
