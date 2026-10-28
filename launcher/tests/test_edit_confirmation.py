"""Exercise the actual confirmation script using fake editor/sudoedit binaries."""

import ast
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "Launcher.qml"


class EditConfirmationTests(unittest.TestCase):
    def setUp(self):
        source = SOURCE.read_text()
        fragment = source[source.index("'printf \"File:"):source.index('"launcher-edit"')]
        self.script = "".join(ast.literal_eval(value) for value in
                              re.findall(r"'(?:[^'\\]|\\.)*'", fragment))
        self.temporary = tempfile.TemporaryDirectory(prefix="launcher-edit-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.log = self.base / "calls.json"
        for name in ("editor", "sudoedit"):
            executable = self.base / name
            executable.write_text(
                f"#!{sys.executable}\nimport json, os, sys\n"
                "from pathlib import Path\n"
                'Path(os.environ["EDIT_TEST_LOG"]).write_text(json.dumps(sys.argv))\n'
            )
            executable.chmod(0o755)

    def run_choice(self, choice, path="/etc/example.conf"):
        result = subprocess.run(
            ["/bin/sh", "-c", self.script, "launcher-edit", path, str(self.base / "editor")],
            input=choice, text=True, capture_output=True, timeout=5,
            env={**os.environ, "PATH": str(self.base), "EDIT_TEST_LOG": str(self.log)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(self.log.read_text()) if self.log.exists() else None

    def test_enter_uses_normal_editor(self):
        command = self.run_choice("\n")
        self.assertEqual(Path(command[0]).name, "editor")
        self.assertEqual(command[1:], ["/etc/example.conf"])

    def test_explicit_choice_uses_sudoedit(self):
        command = self.run_choice("s\n")
        self.assertEqual(Path(command[0]).name, "sudoedit")
        self.assertEqual(command[1:], ["--", "/etc/example.conf"])

    def test_other_input_cancels(self):
        self.assertIsNone(self.run_choice("no\n"))

    def test_eof_cancels(self):
        self.assertIsNone(self.run_choice(""))

    def test_shell_characters_in_path_remain_literal(self):
        path = "/tmp/a file; $(not-a-command) 'quoted'.conf"
        command = self.run_choice("s\n", path)
        self.assertEqual(command[1:], ["--", path])
