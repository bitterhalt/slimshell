"""Exercise the wrapper with fake IPC; never opens the live launcher."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "dmenu-runner"
FAKE_QS = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

base = Path(os.environ["DMENU_TEST_DIR"])
kind = os.environ.get("DMENU_TEST_KIND", "success")
method = sys.argv[4]
if method == "dmenuSession":
    started = (base / "request.json").exists()
    if started and kind == "disappeared":
        sys.exit(1)
    if started and kind == "hung":
        import time
        time.sleep(30)
    print("new-session" if started and kind == "reloaded" else "session")
elif method == "dmenu":
    items, output, prompt, lines, minimal = sys.argv[5:]
    (base / "request.json").write_text(json.dumps({
        "items": Path(items).read_text(), "prompt": prompt, "output": output,
        "lines": int(lines), "minimal": minimal,
    }))
    if kind == "ipc-error":
        sys.exit(1)
    if kind in ("disappeared", "reloaded", "hung", "waiting"):
        sys.exit(0)
    result = "cancel\n" if kind == "cancel" else "ok\n" + os.environ.get("DMENU_TEST_CHOICE", "two") + "\n"
    temporary = Path(output + ".tmp")
    temporary.write_text(result)
    temporary.replace(output)
else:
    sys.exit(2)
'''


class DmenuRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dmenu-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.runtime = self.base / "runtime"
        self.runtime.mkdir()
        fake = self.base / "qs"
        fake.write_text(FAKE_QS)
        fake.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": str(self.base) + os.pathsep + os.environ["PATH"],
            "XDG_RUNTIME_DIR": str(self.runtime),
            "DMENU_TEST_DIR": str(self.base),
        }

    def run_runner(self, *args, kind="success", choice="two", data="one\ntwo\n"):
        result = subprocess.run(
            [str(RUNNER), *args], input=data, text=True, capture_output=True,
            env={**self.env, "DMENU_TEST_KIND": kind, "DMENU_TEST_CHOICE": choice},
            timeout=8,
        )
        self.assertEqual(list(self.runtime.iterdir()), [])
        return result

    def test_success_and_prompt(self):
        result = self.run_runner("-p", "Pick one", "-l", "10", "-i")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "two\n")
        request = json.loads((self.base / "request.json").read_text())
        self.assertEqual(request["prompt"], "Pick one")
        self.assertEqual(request["items"], "one\ntwo\n")
        self.assertEqual(request["lines"], 10)
        self.assertEqual(request["minimal"], "false")

    def test_default_lines(self):
        self.assertEqual(self.run_runner().returncode, 0)
        request = json.loads((self.base / "request.json").read_text())
        self.assertEqual(request["lines"], 7)
        self.assertEqual(request["minimal"], "false")

    def test_line_options(self):
        for args, expected in ((["-l", "3"], 3), (["-l4"], 4),
                               (["--lines", "5"], 5), (["--lines=6"], 6),
                               (["-l", "0"], 0), (["-l", "0008"], 8)):
            with self.subTest(args=args):
                result = self.run_runner(*args, "--minimal-lines")
                self.assertEqual(result.returncode, 0, result.stderr)
                request = json.loads((self.base / "request.json").read_text())
                self.assertEqual(request["lines"], expected)
                self.assertEqual(request["minimal"], "true")

    def test_invalid_lines(self):
        for value in ("", "-1", "1.5", "abc", "10001", "999999999999999999999999"):
            with self.subTest(value=value):
                result = self.run_runner("--lines", value)
                self.assertEqual(result.returncode, 2)
                self.assertIn("lines must be an integer", result.stderr)

    def test_attached_prompt(self):
        self.assertEqual(self.run_runner("-pPick").returncode, 0)
        self.assertEqual(json.loads((self.base / "request.json").read_text())["prompt"], "Pick")

    def test_missing_option_values(self):
        for option in ("-p", "--prompt", "-l", "--lines", "-fn", "-nb", "-nf", "-sb", "-sf", "-m", "-w"):
            with self.subTest(option=option):
                result = self.run_runner(option)
                self.assertEqual(result.returncode, 2)
                self.assertIn("requires a value", result.stderr)
        self.assertFalse((self.base / "request.json").exists())

    def test_cancel(self):
        result = self.run_runner(kind="cancel")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")

    def test_empty_selection_succeeds(self):
        result = self.run_runner(choice="", data="\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "\n")

    def test_input_and_output_are_literal(self):
        choice = '  <b>A & B</b> \\ $(false)  '
        result = self.run_runner(choice=choice, data="\n" + choice + "\n\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, choice + "\n")
        self.assertEqual(json.loads((self.base / "request.json").read_text())["items"], "\n" + choice + "\n\n")

    def test_ipc_error(self):
        self.assertEqual(self.run_runner(kind="ipc-error").returncode, 1)

    def test_consecutive_requests_have_separate_results(self):
        self.assertEqual(self.run_runner(choice="first").stdout, "first\n")
        self.assertEqual(self.run_runner(kind="cancel").returncode, 1)
        self.assertEqual(self.run_runner(choice="last").stdout, "last\n")

    def test_shell_disappears(self):
        self.assertEqual(self.run_runner(kind="disappeared").returncode, 1)

    def test_shell_reloads(self):
        self.assertEqual(self.run_runner(kind="reloaded").returncode, 1)

    def test_unresponsive_ipc_is_bounded(self):
        self.assertEqual(self.run_runner(kind="hung").returncode, 1)

    def test_signal_cleans_up(self):
        with subprocess.Popen(
            [str(RUNNER)], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, env={**self.env, "DMENU_TEST_KIND": "waiting"},
        ) as process:
            try:
                deadline = time.monotonic() + 4
                while not (self.base / "request.json").exists():
                    if time.monotonic() > deadline:
                        self.fail("Wrapper did not submit its request")
                    time.sleep(0.02)
                process.terminate()
                process.communicate(timeout=4)
                self.assertEqual(process.returncode, 143)
                self.assertEqual(list(self.runtime.iterdir()), [])
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()


if __name__ == "__main__":
    unittest.main()
