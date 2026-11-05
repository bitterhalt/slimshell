import QtQuick
import QtTest
import "../../components"

Item {
    id: host
    width: 500
    height: 400

    ControlConfig {
        id: config
    }
    readonly property var controlConfig: config
    Component {
        id: iconButtonComponent
        ShellIconButton {
            config: host.controlConfig
            iconText: "󰑐"
            text: "Scan"
            implicitHeight: 20
            padding: 2
        }
    }
    Component {
        id: buttonComponent
        ShellButton {
            config: host.controlConfig
            text: "Apply"
            width: 120
            height: 32
        }
    }
    Component {
        id: fieldComponent
        ShellTextField {
            config: host.controlConfig
            width: 200
        }
    }
    Component {
        id: rowComponent
        ActionRow {
            config: host.controlConfig
            text: "Forget"
            shortcutText: "[f]"
            width: 240
        }
    }
    Component {
        id: surfaceComponent
        PanelSurface {
            config: host.controlConfig
            width: 200
            height: 100
        }
    }
    Component {
        id: indicatorComponent
        Item {
            width: 100
            height: 40
            SelectionIndicator {
                objectName: "indicator"
                config: host.controlConfig
                selected: true
            }
        }
    }
    SignalSpy {
        id: clickSpy
        signalName: "clicked"
    }

    TestCase {
        name: "SharedControls"
        when: windowShown

        function init() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            clickSpy.target = null;
            clickSpy.clear();
            mouseMove(host, 490, 390);
        }

        function test_button_mouse_keyboard_and_disabled() {
            const button = createTemporaryObject(buttonComponent, host);
            clickSpy.target = button;
            mouseMove(button, 10, 10);
            tryCompare(button, "hovered", true);
            compare(button.background.color, config.selectionBackground);
            compare(button.contentItem.color, config.selectionForeground);
            mouseClick(button, 10, 10);
            compare(clickSpy.count, 1);
            button.forceActiveFocus();
            keyClick(Qt.Key_Space);
            compare(clickSpy.count, 2);
            button.enabled = false;
            mouseClick(button, 10, 10);
            compare(clickSpy.count, 2);
            compare(button.contentItem.color, config.muted);
            verify(button.background.color !== config.selectionBackground);
        }
        function test_icon_uses_explicit_font_and_button_colors() {
            const button = createTemporaryObject(iconButtonComponent, host);
            const icon = findChild(button, "buttonIcon");
            compare(icon.font.family, config.iconFontFamily);
            compare(icon.font.pointSize, config.iconSize);
            button.iconSize = 18;
            compare(icon.font.pointSize, 18);
            compare(icon.renderType, Text.QtRendering);
            compare(icon.text, "󰑐");
            compare(button.height, 20);
            button.forceActiveFocus();
            compare(icon.color, config.selectionForeground);
            button.enabled = false;
            compare(icon.color, config.muted);
        }

        function test_action_row_selection_and_destructive_state() {
            const row = createTemporaryObject(rowComponent, host);
            row.destructive = true;
            verify(!row.visuallyHighlighted);
            row.selected = true;
            compare(row.background.color, config.selectionBackground);
            row.selected = false;
            row.forceActiveFocus();
            verify(row.visuallyHighlighted);
            clickSpy.target = row;
            keyClick(Qt.Key_Space);
            compare(clickSpy.count, 1);
            compare(row.shortcutText, "[f]");
        }

        function test_text_field_editing_selection_and_password() {
            const field = createTemporaryObject(fieldComponent, host);
            field.forceActiveFocus();
            keyClick(Qt.Key_A);
            compare(field.text, "a");
            compare(field.background.border.color, config.selectionBackground);
            compare(field.selectionColor, config.selectionBackground);
            field.echoMode = TextInput.Password;
            field.text = "synthetic";
            verify(field.displayText !== field.text);
            field.clear();
            compare(field.text, "");
        }

        function test_surface_and_selection_geometry() {
            const surface = createTemporaryObject(surfaceComponent, host);
            compare(surface.color, config.bg);
            compare(surface.radius, config.popupRadius);
            compare(surface.border.color, config.border);
            const parent = createTemporaryObject(indicatorComponent, host);
            const indicator = findChild(parent, "indicator");
            compare(indicator.height, 34);
            indicator.verticalInset = 6;
            compare(indicator.height, 28);
            indicator.selected = false;
            verify(!indicator.visible);
        }
    }
}
