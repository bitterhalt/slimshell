"""Drive bar chips offscreen, with an inert tooltip and fake service."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tests.qml_support import copy_control_config, run_qml_tests

ROOT = Path(__file__).resolve().parents[2]


class DrivesUiTests(unittest.TestCase):
    def test_chips_actions_and_compact_staging(self):
        with tempfile.TemporaryDirectory(prefix="drives-ui-") as directory:
            base = Path(directory)
            source = (ROOT / "bar/modules/drives/Drives.qml").read_text()
            (base / "Drives.qml").write_text(source.replace('import "../../../components"', 'import "."').replace(
                'import "../../../services/drives/DriveModel.js"', 'import "DriveModel.js"'))
            (base / "DriveModel.js").write_text(
                (ROOT / "services/drives/DriveModel.js").read_text()
            )
            (base / "ShellToolTip.qml").write_text((ROOT / "tests/fixtures/ShellToolTip.qml").read_text())
            fixture = (ROOT / "tests/drives/DrivesFixture.qml").read_text()
            (base / "tst_drives.qml").write_text(fixture.replace('import "../components"', 'import "."'))
            copy_control_config(base)
            run_qml_tests(directory)
