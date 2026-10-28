"""The test runner itself is exercised with subprocess doubles only."""

import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location("offline_runner", Path(__file__).with_name("run.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def test_qt6_is_preferred_over_generic_path_tool(self):
        with patch.dict(runner.os.environ, {"QMLTESTRUNNER": ""}), \
                patch.object(runner.shutil, "which", side_effect=lambda name:
                             "/qt5/qmltestrunner" if name == "qmltestrunner" else None), \
                patch.object(runner.os, "access", return_value=True):
            self.assertEqual(runner.qml_runner(), "/usr/lib/qt6/bin/qmltestrunner")

    def test_list_does_not_run_commands(self):
        with patch.object(runner, "run_suite") as run, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(["--list"]), 0)
            run.assert_not_called()

    def test_selected_feature_runs_only_its_suites_once(self):
        with patch.object(runner, "run_suite", return_value=(True, "passed")) as run, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(["network", "network"]), 0)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[:2], ("qml", "bar/modules/network/tests"))

    def test_failure_does_not_skip_remaining_suites(self):
        with patch.object(runner, "run_suite", side_effect=[(False, "failed"), (True, "passed")]) as run, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(["launcher"]), 1)
        self.assertEqual(run.call_count, 2)

    def test_unknown_feature_fails_before_running(self):
        with patch.object(runner, "run_suite") as run, contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                runner.main(["live-shell"])
            self.assertEqual(error.exception.code, 2)
            run.assert_not_called()

    def test_python_uses_offscreen_no_bytecode_and_checkout_root(self):
        result = Mock(returncode=0, stdout="", stderr="Ran 3 tests in 0.1s\n\nOK\n")
        with patch.object(runner.subprocess, "run", return_value=result) as run:
            passed, summary = runner.run_suite("python", "launcher/tests", None)
        self.assertTrue(passed)
        self.assertIn("Ran 3 tests", summary)
        self.assertIn("-B", run.call_args.args[0])
        self.assertEqual(run.call_args.kwargs["cwd"], runner.ROOT)
        self.assertEqual(run.call_args.kwargs["env"]["QT_QPA_PLATFORM"], "offscreen")
        self.assertEqual(run.call_args.kwargs["env"]["PYTHONDONTWRITEBYTECODE"], "1")

    def test_missing_qt_runner_fails_without_launching_anything(self):
        with patch.object(runner.subprocess, "run") as run:
            passed, detail = runner.run_suite("qml", "components/tests", None)
        self.assertFalse(passed)
        self.assertIn("not found", detail)
        run.assert_not_called()

    def test_timeout_is_reported_as_failure(self):
        with patch.object(runner.subprocess, "run", side_effect=subprocess.TimeoutExpired("test", 120)):
            passed, detail = runner.run_suite("python", "tests", None)
        self.assertFalse(passed)
        self.assertIn("timed out", detail)
