"""Exercise the launcher's actual search handlers with offline process doubles."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "Launcher.qml"


def block(text, marker):
    start = text.index("{", text.index(marker))
    depth = 1
    end = start + 1
    while depth:
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    return text[start:end]


class FileSearchTests(unittest.TestCase):
    def test_cancellation_generations(self):
        source = SOURCE.read_text()
        process = source[source.index("        id: fileProcess"):]
        handlers = (
            "function updateFileSearch() " + block(source, "function updateFileSearch()"),
            "function processExited() " + block(process, "onExited:"),
            "function receiveOutput(text) " + block(process, "onStreamFinished:"),
        )
        fixture = r'''
import QtQuick
import QtTest
Item {
    id: root
    property bool opened: true
    property bool fileMode: true
    property string fileNeedle: "foo"
    property var fileResults: []
    property int selectedIndex: 0
    property int fileSearchGeneration: 0
    property bool fileSearchPending: false
    property int kills: 0
    property var fileProcess: ({running: false, generation: -1,
        signal: function(number) { root.kills++; }})
    function fileItem(path) { return path; }
    QtObject {
        id: fileSearchDebounce
        property int restarts: 0
        function stop() {}
        function restart() { restarts++; }
    }
    HANDLERS
    TestCase {
        name: "LauncherFileSearchCancellation"
        function init() {
            root.opened = true;
            root.fileMode = true;
            root.fileNeedle = "foo";
            root.fileSearchGeneration = 0;
            root.fileSearchPending = false;
            root.fileResults = [];
            root.fileProcess.running = true;
            root.fileProcess.generation = -1;
            root.kills = 0;
            fileSearchDebounce.restarts = 0;
        }
        function test_returning_to_cancelled_query_restarts() {
            root.fileNeedle = "bar";
            root.updateFileSearch();
            root.fileNeedle = "foo";
            root.updateFileSearch();
            compare(root.kills, 2);
            root.fileProcess.running = false;
            root.processExited();
            compare(fileSearchDebounce.restarts, 1);
            root.receiveOutput("stale result");
            compare(root.fileResults.length, 0);
        }
        function test_closing_does_not_restart() {
            root.opened = false;
            root.updateFileSearch();
            root.fileProcess.running = false;
            root.processExited();
            compare(fileSearchDebounce.restarts, 0);
            root.receiveOutput("late result");
            compare(root.fileResults.length, 0);
        }
        function test_current_generation_is_accepted() {
            root.receiveOutput("first\nsecond\n");
            compare(root.fileResults.length, 0);
            root.fileProcess.generation = root.fileSearchGeneration;
            root.receiveOutput("first\nsecond\n");
            compare(root.fileResults.length, 2);
        }
    }
}
'''.replace("HANDLERS", "\n".join(handlers))
        with tempfile.TemporaryDirectory(prefix="launcher-search-") as directory:
            Path(directory, "tst_search.qml").write_text(fixture)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
