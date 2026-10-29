#!/usr/bin/env python3
"""Run explicitly listed offline suites; never start the live shell."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
# Explicit paths keep future live/integration tests out of the default run.
SUITES = {
    "components": [("qml", "components/tests")],
    "notifications": [("qml", "notifications/tests")],
    "audio": [("qml", "bar/modules/audio/tests")],
    "bluetooth": [("qml", "bar/modules/bluetooth/tests"),
                  ("qml", "services/bluetooth/tests")],
    "network": [("qml", "bar/modules/network/tests")],
    "workspaces": [("qml", "bar/modules/workspaces/tests")],
    "idle": [("qml", "services/idle/tests")],
    "launcher": [("qml", "launcher/tests"), ("python", "launcher/tests")],
    "translator": [("qml", "translator/tests"), ("python", "translator")],
    "wallpaper": [("qml", "wallpaper/tests"), ("python", "wallpaper")],
    "clipboard": [("python", "clipboard/tests")],
    "battery": [("python", "services/battery/tests")],
    "services": [("python", "services/tests")],
    "runner": [("python", "tests")],
}


def qml_runner():
    # A generic PATH executable may be Qt 5; prefer explicitly Qt 6 tools.
    candidates = [os.environ.get("QMLTESTRUNNER"), shutil.which("qmltestrunner6"),
                  "/usr/lib/qt6/bin/qmltestrunner", "/usr/lib64/qt6/bin/qmltestrunner",
                  shutil.which("qmltestrunner")]
    return next((path for path in candidates if path and os.access(path, os.X_OK)), None)


def run_suite(kind, path, qt_runner):
    if kind == "qml":
        if not qt_runner:
            return False, "qmltestrunner not found; install Qt Test or set QMLTESTRUNNER."
        command = [qt_runner, "-input", path, "-o", "-,txt"]
    else:
        command = [sys.executable, "-B", "-m", "unittest", "discover", "-s", path]
    environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen",
                   "PYTHONDONTWRITEBYTECODE": "1"}
    try:
        result = subprocess.run(command, cwd=ROOT, env=environment,
                                capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as error:
        return False, str(error)
    output = result.stdout + result.stderr
    if result.returncode:
        return False, f"exit code {result.returncode}\n{output}"
    summary = [line.strip() for line in output.splitlines()
               if line.startswith("Totals:") or line.startswith("Ran ")]
    return True, " · ".join(summary) or "passed"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("features", nargs="*", metavar="FEATURE",
                        help="Feature names from --list; defaults to all offline suites.")
    parser.add_argument("--list", action="store_true", help="List available features and exit.")
    args = parser.parse_args(argv)
    if args.list:
        print("\n".join(SUITES))
        return 0
    unknown = [name for name in args.features if name not in SUITES]
    if unknown:
        parser.error("unknown feature(s): " + ", ".join(unknown) + "; use --list")
    selected = list(dict.fromkeys(args.features)) or list(SUITES)
    qt_runner = qml_runner()
    failures = 0
    total = 0
    for feature in selected:
        for kind, path in SUITES[feature]:
            total += 1
            label = f"{feature} [{kind}: {path}]"
            print(f"Running {label}", flush=True)
            passed, detail = run_suite(kind, path, qt_runner)
            print(f"{'PASS' if passed else 'FAIL'}: {detail}", flush=True)
            failures += not passed
    print(f"\n{total - failures}/{total} offline suites passed.")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
