import QtQuick

Item {
    id: root

    required property var device
    readonly property bool connected: !!device && device.connected
    readonly property bool ready: connected && device.paired && !device.pairing
    property bool initialized: false
    property bool notified: false

    signal connectionReady(var device)

    visible: false
    onConnectedChanged: {
        if (!connected)
            notified = false;
        checkConnection();
    }
    onReadyChanged: checkConnection()
    Component.onCompleted: {
        // Existing connections should not produce toasts on startup/reload.
        notified = ready;
        initialized = true;
    }

    function checkConnection() {
        if (!initialized || !ready || notified)
            return;
        notified = true;
        connectionReady(device);
    }
}
