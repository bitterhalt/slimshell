"""Privacy controls offscreen, without mapping Quickshell tooltip surfaces."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PrivacyUiTests(unittest.TestCase):
    def test_indicators_and_click_actions(self):
        with tempfile.TemporaryDirectory(prefix="privacy-ui-") as directory:
            base = Path(directory)
            source = (ROOT / "bar/modules/privacy/Privacy.qml").read_text()
            (base / "Privacy.qml").write_text(source.replace('"../../../components"', '"."'))
            (base / "ShellToolTip.qml").write_text((ROOT / "tests/fixtures/ShellToolTip.qml").read_text())
            (base / "Model.js").write_text((ROOT / "services/privacy/Model.js").read_text())
            (base / "tst_privacy.qml").write_text((ROOT / "tests/privacy/PrivacyFixture.qml").read_text())
            result = subprocess.run(
                ["/usr/lib/qt6/bin/qmltestrunner", "-input", directory, "-o", "-,txt"],
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
                capture_output=True, text=True, timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
