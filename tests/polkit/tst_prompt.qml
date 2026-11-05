import QtQuick
import QtTest
import "../../polkit"
import "../components"

Item {
    id: host
    width: 500
    height: 500
    ControlConfig {
        id: config
    }
    readonly property var controlConfig: config
    readonly property var promptFlow: flow
    QtObject {
        id: flow
        property string message: "Synthetic authentication"
        property string actionId: "test.action"
        property var identities: [
            {
                displayName: "Test One"
            },
            {
                displayName: "Test Two"
            }
        ]
        property var selectedIdentity: identities[0]
        property bool isResponseRequired: true
        property bool responseVisible: false
        property string inputPrompt: "Password"
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
    }
    Component {
        id: promptComponent
        PolkitPrompt {
            config: host.controlConfig
            flow: host.promptFlow
            width: 390
            height: implicitHeight
        }
    }
    SignalSpy {
        id: submitSpy
        signalName: "submitted"
    }
    SignalSpy {
        id: cancelSpy
        signalName: "cancelled"
    }
    SignalSpy {
        id: identitySpy
        signalName: "identitySelected"
    }

    TestCase {
        name: "PolkitPromptView"
        when: windowShown

        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            flow.isResponseRequired = true;
            flow.responseVisible = false;
            for (const spy of [submitSpy, cancelSpy, identitySpy]) {
                spy.target = null;
                spy.clear();
            }
        }

        function test_response_focus_submit_clear_and_cancel() {
            const prompt = createTemporaryObject(promptComponent, host);
            submitSpy.target = prompt;
            cancelSpy.target = prompt;
            prompt.focusPrompt();
            const field = findChild(prompt, "polkitResponseField");
            tryCompare(field, "activeFocus", true);
            prompt.response = "synthetic";
            verify(field.displayText !== prompt.response);
            keyClick(Qt.Key_Return);
            compare(submitSpy.count, 1);
            prompt.clearResponse();
            compare(prompt.response, "");
            keyClick(Qt.Key_Escape);
            compare(cancelSpy.count, 1);
            flow.responseVisible = true;
            prompt.response = "visible response";
            compare(field.displayText, prompt.response);
        }

        function test_no_response_focus_and_identity_intent() {
            const prompt = createTemporaryObject(promptComponent, host);
            identitySpy.target = prompt;
            const picker = findChild(prompt, "polkitIdentityPicker");
            picker.activated(1);
            compare(identitySpy.signalArguments[0][0], 1);
            // The view must not mutate authentication state itself.
            compare(flow.selectedIdentity, flow.identities[0]);
            flow.isResponseRequired = false;
            prompt.focusPrompt();
            tryCompare(findChild(prompt, "polkitCancelButton"), "activeFocus", true);
            verify(!findChild(prompt, "polkitResponseField").visible);
            verify(!findChild(prompt, "polkitSubmitButton").visible);
        }
    }
}
