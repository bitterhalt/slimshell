import QtQuick
import QtTest
import ".."

Item {
    id: host

    width: 500
    height: 80

    QtObject {
        id: fixtureConfig

        property int barModuleSpacing: 8
        property color urgent: "red"
        property color selectionBackground: "orange"
        property color selectionForeground: "black"
        property color fg: "white"
        property var commands: []

        function fontSize(scale) { return 12 * scale; }
        function run(command) { commands = commands.concat([command]); }
    }

    QtObject {
        id: fixtureSettings
        property string workspaceLayout: "dots"
        property bool settingsLoaded: true
        function saveWorkspaceLayout(layout) {
            workspaceLayout = layout;
            return "";
        }
    }

    QtObject {
        id: fixtureScreen
        property string name: "A"
    }

    QtObject {
        id: fixtureBar
        property int height: 32
        property var screen: fixtureScreen
    }

    QtObject {
        id: fixtureNiri
        property var workspaces: [
            {id: 1, idx: 1, name: "Web", output: "A", is_active: true, is_urgent: false},
            {id: 2, idx: 2, name: "Code", output: "A", is_active: false, is_urgent: true},
            {id: 3, idx: 3, name: "Notes", output: "A", is_active: false, is_urgent: false},
            {id: 4, idx: 1, name: "Other screen", output: "B", is_active: false, is_urgent: false}
        ]
    }

    Workspaces {
        id: workspaces
        config: fixtureConfig
        barWindow: fixtureBar
        niri: fixtureNiri
        settingsService: fixtureSettings
    }

    TestCase {
        name: "Workspaces"
        when: windowShown

        function init() {
            fixtureSettings.workspaceLayout = "dots";
            fixtureConfig.commands = [];
            workspaces.layoutAnimationRequested = false;
        }

        function test_dots_remain_default_and_clickable() {
            verify(findChild(workspaces, "workspace-dot-1") !== null);
            verify(findChild(workspaces, "workspace-dot-2") !== null);
            verify(findChild(workspaces, "workspace-dot-3") !== null);
            compare(findChild(workspaces, "workspace-dot-4"), null);
            mouseClick(findChild(workspaces, "workspace-dot-2"));
            compare(fixtureConfig.commands, ["niri msg action focus-workspace 2"]);
        }

        function test_right_click_toggles_layout() {
            mouseClick(workspaces, workspaces.width / 2, workspaces.height / 2, Qt.RightButton);
            compare(fixtureSettings.workspaceLayout, "minimal");
            mouseClick(workspaces, workspaces.width / 2, workspaces.height / 2, Qt.RightButton);
            compare(fixtureSettings.workspaceLayout, "dots");
        }

        function test_minimal_shows_active_name_and_reveals_rest() {
            fixtureSettings.workspaceLayout = "minimal";
            wait(1);

            const revealer = findChild(workspaces, "workspaceRevealer");
            const chip = findChild(workspaces, "activeWorkspaceChip");
            const activeName = findChild(workspaces, "activeWorkspaceName");
            compare(activeName.text, "Web");
            compare(chip.color, fixtureConfig.selectionBackground);
            compare(chip.radius, 4);
            compare(chip.height, 26);
            compare(activeName.color, fixtureConfig.selectionForeground);
            const dots = findChild(workspaces, "dotsRow");
            tryCompare(dots, "opacity", 0, 300);
            verify(findChild(workspaces, "workspace-dot-1") === null
                || !findChild(workspaces, "workspace-dot-1").visible);

            const collapsedWidth = workspaces.implicitWidth;
            mouseMove(workspaces, 4, workspaces.height / 2);
            wait(150);
            compare(revealer.revealProgress, 0);
            tryCompare(revealer, "revealProgress", 1);
            verify(workspaces.implicitWidth > collapsedWidth);

            const codeName = findChild(workspaces, "workspace-name-2");
            verify(codeName !== null);
            compare(codeName.text, "Code");
            compare(codeName.parent.color, fixtureConfig.urgent);
            compare(codeName.parent.opacity, 0.8);
            const notesName = findChild(workspaces, "workspace-name-3");
            verify(notesName !== null);
            compare(notesName.parent.color, fixtureConfig.selectionBackground);
            compare(notesName.parent.opacity, 0.8);
            mouseClick(codeName, codeName.width / 2, codeName.height / 2);
            compare(fixtureConfig.commands, ["niri msg action focus-workspace 2"]);
        }
    }
}
