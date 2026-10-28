"""Exercise real launcher backends with inert processes and in-memory files."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]

TEST = r'''
import QtQuick
import QtTest
import "."
Item {
    id: host
    Component { id: files; FileSearchState { active: false; needle: "" } }
    Component { id: calculator; CalculatorState { active: false; query: ""; expression: "" } }
    Component { id: emoji; EmojiState { active: false; query: "" } }
    Component { id: run; RunState { active: false; query: "" } }
    TestCase {
        name: "LauncherBackends"
        function init() { failOnWarning(/TypeError|Binding loop|ReferenceError/); }
        function job(state) {
            return Array.from(state.data).find(child => child.generation !== undefined);
        }
        function finish(process, output, code) {
            process.stdout.text = output;
            process.stdout.streamFinished();
            process.running = false;
            process.exited(code || 0);
        }
        function test_cancelled_query_restarts_even_when_query_returns() {
            const state = createTemporaryObject(files, host);
            state.needle = "foo";
            state.active = true;
            const process = job(state);
            tryCompare(process, "running", true);
            const previous = process.generation;
            state.needle = "bar";
            state.needle = "foo";
            verify(state.generation > previous);
            verify(process.signalCount >= 2);
            finish(process, "/stale/foo\n");
            compare(state.results.length, 0);
            tryCompare(process, "running", true);
            compare(process.generation, state.generation);
            finish(process, "/current/foo\n");
            compare(state.results.length, 1);
            compare(state.results[0].path, "/current/foo");
        }
        function test_leaving_files_discards_output_and_stops_restarts() {
            const state = createTemporaryObject(files, host);
            state.needle = "foo";
            state.active = true;
            const process = job(state);
            tryCompare(process, "running", true);
            state.active = false;
            finish(process, "/late/foo\n");
            wait(220);
            verify(!process.running);
            compare(state.results.length, 0);
        }
        function test_short_file_queries_do_not_start_search() {
            const state = createTemporaryObject(files, host);
            state.active = true;
            state.needle = "x";
            wait(220);
            verify(!state.busy);
            verify(!job(state).running);
        }
        function test_calculator_normalization_and_late_results() {
            const state = createTemporaryObject(calculator, host);
            compare(state.normalizeExpression("2x3 × 4 ÷ 2"), "2*3 * 4 / 2");
            compare(state.normalizeExpression("0x1F"), "0x1F");
            state.query = "1+2";
            state.expression = "1+2";
            state.active = true;
            const process = job(state);
            tryCompare(process, "running", true);
            state.active = false;
            finish(process, "3\n");
            compare(state.result, "");
            state.active = true;
            tryCompare(process, "running", true);
            finish(process, "3\n");
            compare(state.result, "3");
        }
        function test_calculator_reschedules_query_changed_while_busy() {
            const state = createTemporaryObject(calculator, host);
            state.query = "1+2";
            state.expression = "1+2";
            state.active = true;
            const process = job(state);
            tryCompare(process, "running", true);
            state.query = "2+2";
            state.expression = "2+2";
            wait(150);
            finish(process, "3\n");
            compare(state.result, "");
            tryCompare(process, "running", true);
            compare(process.command[2], "2+2");
            finish(process, "4\n");
            compare(state.result, "4");
        }
        function test_emoji_loads_lazily_and_preserves_pending_history() {
            const state = createTemporaryObject(emoji, host);
            verify(!state.dataRequested);
            state.record("🐀");
            state.restoreHistory('["😀"]');
            compare(state.history, ["🐀", "😀"]);
            state.active = true;
            verify(state.dataRequested);
            state.entries = [{emoji: "🐀", name: "rat"}, {emoji: "😀", name: "grinning face"}];
            state.query = "rat";
            compare(state.results.length, 1);
            compare(state.results[0].emoji, "🐀");
            state.active = false;
            compare(state.results.length, 0);
        }
        function test_run_quotes_arguments_and_recent_ranking() {
            const state = createTemporaryObject(run, host);
            state.binaries = ["firefox", "foot", "find"];
            state.history = ["firefox", "foot", "firefox"];
            state.active = true;
            compare(state.results[0].text, "firefox");
            state.query = 'foot "two words" \'literal\' escaped\\ space';
            compare(state.name, "foot");
            compare(state.args, ["two words", "literal", "escaped space"]);
            state.record("foot");
            compare(state.history, ["firefox", "firefox", "foot"]);
            state.active = false;
            compare(state.results.length, 0);
        }
    }
}
'''


class BackendTests(unittest.TestCase):
    def test_offline_backends(self):
        with tempfile.TemporaryDirectory(prefix="launcher-backends-") as directory:
            base = Path(directory)
            for name in ("CalculatorState", "FileSearchState", "RunState", "EmojiState"):
                source = (ROOT / f"{name}.qml").read_text()
                source = "\n".join(line for line in source.splitlines()
                                   if not line.startswith("import Quickshell"))
                (base / f"{name}.qml").write_text('import "."\n' + source)
            for name in ("Scorer.js", "Emoji.js"):
                (base / name).write_text((ROOT / name).read_text())
            (base / "qmldir").write_text("singleton Quickshell 1.0 Quickshell.qml\n")
            (base / "Quickshell.qml").write_text(
                'pragma Singleton\nimport QtQuick\nQtObject {\n'
                'function env(name) { return "/synthetic-home"; }\n'
                'function execDetached(command) { throw new Error("Unexpected command"); }\n}\n'
            )
            doubles = {
                "Process": '''QtObject {
                    property bool running: false
                    property var command: []
                    property QtObject stdout
                    property QtObject stderr
                    property int signalCount: 0
                    function signal(number) { signalCount++; }
                    signal exited(int exitCode)
                }''',
                "StdioCollector": '''QtObject {
                    property string text: ""
                    signal streamFinished()
                }''',
                "FileView": '''QtObject {
                    property string path: ""
                    property bool atomicWrites: false
                    property bool watchChanges: false
                    property bool printErrors: false
                    property string contents: ""
                    property string written: ""
                    function text() { return contents; }
                    function setText(value) { written = value; }
                    function reload() {}
                    signal loaded()
                    signal loadFailed()
                }''',
            }
            for name, body in doubles.items():
                (base / f"{name}.qml").write_text("import QtQuick\n" + body)
            (base / "tst_backends.qml").write_text(TEST)
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
