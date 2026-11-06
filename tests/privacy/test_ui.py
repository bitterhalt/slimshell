"""Privacy controls offscreen, without mapping Quickshell tooltip surfaces."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import copy_control_config, run_qml_tests

ROOT = Path(__file__).resolve().parents[2]


class PrivacyUiTests(unittest.TestCase):
    def test_indicators_and_click_actions(self):
        with tempfile.TemporaryDirectory(prefix="privacy-ui-") as directory:
            base = Path(directory)
            source = (ROOT / "bar/modules/privacy/Privacy.qml").read_text()
            (base / "Privacy.qml").write_text(source.replace('"../../../components"', '"."'))
            (base / "ShellToolTip.qml").write_text((ROOT / "tests/fixtures/ShellToolTip.qml").read_text())
            (base / "Model.js").write_text((ROOT / "services/privacy/Model.js").read_text())
            fixture = (ROOT / "tests/privacy/PrivacyFixture.qml").read_text()
            (base / "tst_privacy.qml").write_text(fixture.replace('import "../components"', 'import "."'))
            copy_control_config(base)
            run_qml_tests(directory)
