import QtQuick
import QtTest
import "../../menus/MenuSchema.js" as Schema

TestCase {
    name: "MenuSchema"

    function test_commands_actions_and_page_links() {
        const parsed = Schema.parse(JSON.stringify({"user-menu3": [
            {label: "Terminal", shortcut: "T", command: "foot"},
            {label: "Idle", action: "idleSettings"},
            {label: "Power", page: "power"},
            {label: "Confirm", command: "echo example", confirm: true}
        ]}));
        compare(parsed["user-menu3"].length, 4);
        compare(parsed["user-menu3"][0].shortcut, "t");
        compare(parsed["user-menu3"][1].icon, "");
        compare(parsed["user-menu1"].length, 0);
        compare(parsed["user-menu2"].length, 0);
        compare(parsed["user-menu4"].length, 0);
    }
    function test_invalid_documents_data() {
        return [
            {tag: "malformed", value: "{"},
            {tag: "null", value: "null"},
            {tag: "array", value: "[]"},
            {tag: "typo-page", value: '{"sytem":[]}'},
            {tag: "not-array", value: '{"user-menu3":{}}'},
            {tag: "null-item", value: '{"user-menu3":[null]}'},
            {tag: "empty-label", value: '{"user-menu3":[{"label":"","command":"foot"}]}'},
            {tag: "empty-command", value: '{"user-menu3":[{"label":"X","command":" "}]}'},
            {tag: "bad-icon", value: '{"user-menu3":[{"label":"X","command":"foot","icon":1}]}'},
            {tag: "multiple-actions", value: '{"user-menu3":[{"label":"X","command":"foot","action":"lock"}]}'},
            {tag: "unknown-action", value: '{"user-menu3":[{"label":"X","action":"oops"}]}'},
            {tag: "unknown-link", value: '{"user-menu3":[{"label":"X","page":"oops"}]}'},
            {tag: "confirm-action", value: '{"user-menu3":[{"label":"X","action":"lock","confirm":true}]}'},
            {tag: "invalid-shortcut", value: '{"user-menu3":[{"label":"X","command":"foot","shortcut":"ab"}]}'},
            {tag: "unknown-field", value: '{"user-menu3":[{"label":"X","comand":"foot"}]}'},
            {tag: "duplicate-shortcut", value: JSON.stringify({"user-menu3": [
                {label: "A", command: "foot", shortcut: "a"},
                {label: "B", command: "foot", shortcut: "A"}
            ]})}
        ];
    }
    function test_invalid_documents(data) {
        let rejected = false;
        try { Schema.parse(data.value); } catch (_) { rejected = true; }
        verify(rejected);
    }
}
