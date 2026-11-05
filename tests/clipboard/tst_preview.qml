import QtQuick
import QtTest
import "../../clipboard"
import "../components"

Item {
    id: host
    width: 400
    height: 300
    ControlConfig {
        id: fixtureConfig
    }
    Component {
        id: previewComponent
        ClipboardPreview {
            config: fixtureConfig
            entry: null
            width: 300
            height: 200
        }
    }
    Component {
        id: rowComponent
        ClipboardHistoryRow {
            config: fixtureConfig
            entry: ({
                    isImage: false
                })
            width: 160
            height: 32
        }
    }
    TestCase {
        name: "ClipboardPreviewView"
        when: windowShown

        function test_history_row_selection_and_kind() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const row = createTemporaryObject(rowComponent, host);
            const label = findChild(row, "clipboardHistoryLabel");
            compare(label.text, "Text");
            compare(label.color, fixtureConfig.fg);
            row.entry = {
                isImage: true
            };
            row.selected = true;
            compare(label.text, "Image");
            compare(label.color, fixtureConfig.selectionForeground);
        }

        function test_empty_and_text_states() {
            failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
            const preview = createTemporaryObject(previewComponent, host);
            const empty = findChild(preview, "clipboardPreviewEmpty");
            const text = findChild(preview, "clipboardPreviewText");
            verify(empty.visible);
            compare(empty.text, "Clipboard history is empty");
            preview.historyEmpty = false;
            compare(empty.text, "Select an item to preview");
            preview.entry = {
                isImage: false
            };
            preview.previewText = "Synthetic clipboard text";
            verify(!empty.visible);
            verify(text.visible);
            compare(text.text, preview.previewText);
            preview.entry = null;
            verify(!text.visible);
        }
    }
}
