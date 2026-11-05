import QtQuick
import QtTest
import "../../bar/modules/network"
import "../components"

Item {
    id: host
    width: 400
    height: 400
    ControlConfig {
        id: config
    }
    readonly property var controlConfig: config
    Component {
        id: actionsComponent
        NetworkActions {
            config: host.controlConfig
            ssid: "Synthetic"
            selectedNetwork: ({
                    connected: false
                })
            width: 280
        }
    }
    Component {
        id: passwordComponent
        NetworkPasswordForm {
            config: host.controlConfig
            ssid: "Synthetic"
            width: 280
        }
    }
    SignalSpy {
        id: actionSpy
        signalName: "activated"
    }
    SignalSpy {
        id: submitSpy
        signalName: "submitted"
    }
    SignalSpy {
        id: cancelSpy
        signalName: "cancelled"
    }

    TestCase {
        name: "NetworkViews"
        when: windowShown

        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            for (const spy of [actionSpy, submitSpy, cancelSpy]) {
                spy.target = null;
                spy.clear();
            }
        }

        function test_actions_focus_navigation_and_click() {
            const actions = createTemporaryObject(actionsComponent, host);
            actionSpy.target = actions;
            const connect = findChild(actions, "networkConnectAction");
            const forget = findChild(actions, "networkForgetAction");
            compare(connect.text, "Connect");
            actions.focusAction(0);
            tryCompare(connect, "activeFocus", true);
            keyClick(Qt.Key_Tab);
            tryCompare(forget, "activeFocus", true);
            keyClick(Qt.Key_Space);
            compare(actionSpy.signalArguments[0][0], 1);
            actions.selectedNetwork = {
                connected: true
            };
            compare(connect.text, "Disconnect");
            compare(connect.shortcutText, "[d]");
            mouseClick(connect, 10, 10);
            compare(actionSpy.signalArguments[1][0], 0);
        }

        function test_password_submission_and_cancel() {
            const form = createTemporaryObject(passwordComponent, host);
            submitSpy.target = form;
            cancelSpy.target = form;
            form.focusInput();
            const input = findChild(form, "networkPasswordInput");
            const submit = findChild(form, "networkSubmitPassword");
            tryCompare(input, "activeFocus", true);
            verify(!submit.enabled);
            keyClick(Qt.Key_Return);
            compare(submitSpy.count, 0);
            form.text = "synthetic-password";
            verify(input.displayText !== form.text);
            keyClick(Qt.Key_Return);
            compare(submitSpy.count, 1);
            compare(submitSpy.signalArguments[0][0], "synthetic-password");
            keyClick(Qt.Key_Tab);
            keyClick(Qt.Key_Space);
            compare(cancelSpy.count, 1);
            form.text = "";
            verify(!submit.enabled);
        }
    }
}
