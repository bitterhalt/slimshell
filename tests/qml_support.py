"""Shared helpers for QML tests run against ephemeral offscreen fixtures."""

import os
from pathlib import Path
import subprocess

from tests.run import qml_runner


ROOT = Path(__file__).resolve().parents[1]


def copy_control_config(directory):
    """Copy the shared fixture config beside a test's other QML files."""
    (Path(directory) / "ControlConfig.qml").write_text(
        (ROOT / "tests/components/ControlConfig.qml").read_text()
    )


def run_qml_tests(directory, timeout=20):
    """Run all QML tests in directory, raising with the full log on failure."""
    runner = qml_runner()
    if not runner:
        raise RuntimeError("qmltestrunner not found; install Qt Test or set QMLTESTRUNNER.")
    result = subprocess.run(
        [runner, "-input", str(directory), "-o", "-,txt"],
        env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
        capture_output=True, text=True, timeout=timeout,
    )
    if result.returncode != 0:
        raise AssertionError(result.stdout + result.stderr)
    return result
