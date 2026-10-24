"""Offline tests: never run desktop commands or write the real wallpaper/cache."""

import argparse
import contextlib
import fcntl
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import setbg


OUTPUTS = {
    "small": {"current_mode": 0, "modes": [{"width": 1920, "height": 1080}]},
    "large": {"current_mode": 1, "modes": [
        {"width": 1280, "height": 720}, {"width": 2560, "height": 1440}]},
    "off": {"current_mode": None, "modes": [{"width": 3840, "height": 2160}]},
}


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)

    def test_largest_active_mode(self):
        self.assertEqual(setbg.resolution(OUTPUTS), (2560, 1440))
        with self.assertRaises(ValueError):
            setbg.resolution({"off": OUTPUTS["off"]})

    def test_dark_offset_validation(self):
        self.assertEqual(setbg.dark_offset("0.3"), 0.3)
        self.assertEqual(setbg.dark_offset("1"), 1)
        for value in ("red", "-0.1", "1.1", "nan", "inf"):
            with self.assertRaises(argparse.ArgumentTypeError):
                setbg.dark_offset(value)

    def test_recursive_images_only(self):
        (self.folder / "nested").mkdir()
        for name in ("b.PNG", "nested/a image.webp", "notes.txt"):
            (self.folder / name).touch()
        self.assertEqual([p.name for p in setbg.image_paths(self.folder)],
                         ["b.PNG", "a image.webp"])
        with self.assertRaises(ValueError):
            setbg.image_paths(self.folder / "missing")

    def test_thumbnail_cache_invalidates(self):
        image = self.folder / "a.png"
        image.write_bytes(b"image")
        before = setbg.thumbnail_path(image, self.folder)
        image.write_bytes(b"changed image")
        self.assertNotEqual(before, setbg.thumbnail_path(image, self.folder))
        before = setbg.thumbnail_path(image, self.folder)
        stat = image.stat()
        os.utime(image, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1))
        self.assertNotEqual(before, setbg.thumbnail_path(image, self.folder))

    @patch.object(setbg, "run")
    def test_cached_thumbnail_skips_conversion(self, run):
        image = self.folder / "a.png"
        image.touch()
        cached = setbg.thumbnail_path(image, self.folder)
        cached.write_bytes(b"cached")
        self.assertEqual(setbg.thumbnail(image, self.folder), cached)
        run.assert_not_called()

    @patch.object(setbg, "run", side_effect=RuntimeError("bad image"))
    def test_failed_thumbnail_cleans_temporary_file(self, run):
        image = self.folder / "a.png"
        image.touch()
        cache = self.folder / "cache"
        with self.assertRaises(RuntimeError):
            setbg.thumbnail(image, cache)
        self.assertEqual(list(cache.iterdir()), [])

    def test_listing_preserves_special_names_and_reports_bad_previews(self):
        image = self.folder / 'snow ☃ "quote".png'
        image.touch()
        output = io.StringIO()
        with patch.object(setbg, "thumbnail", side_effect=RuntimeError("bad")), \
                contextlib.redirect_stdout(output):
            setbg.list_images(self.folder, self.folder / "cache")
        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(records[0]["path"], str(image))
        self.assertEqual(records[0]["thumbnail"], "")
        self.assertEqual(records[-1], {"done": True, "count": 1, "failed": 1})

    @patch.object(setbg.subprocess, "run")
    def test_command_failure_propagates(self, run):
        run.return_value = subprocess.CompletedProcess([], 1, "", "hellwal failed")
        with self.assertRaisesRegex(RuntimeError, "hellwal failed"):
            setbg.run(["hellwal", "-i", "wall.png"])

    def fake_run(self, cmd, **kwargs):
        self.calls.append(cmd)
        if cmd[0] == "niri":
            return json.dumps(OUTPUTS)
        if cmd[0] == "magick":
            Path(cmd[-1]).write_bytes(b"generated")
        return ""

    def test_apply_creates_both_images_without_theme_commands(self):
        self.calls = []
        image = self.folder / "--special name.png"
        image.touch()
        wall_dir = self.folder / "wall"
        with patch.object(setbg, "WALL_DIR", wall_dir), \
                patch.object(setbg, "run", side_effect=self.fake_run):
            setbg.apply_wallpaper(image)
        self.assertTrue((wall_dir / "wallpaper.png").is_file())
        self.assertTrue((wall_dir / "lockscreen.png").is_file())
        self.assertEqual([cmd[0] for cmd in self.calls],
                         ["niri", "magick", "magick", "awww", "awww"])
        self.assertIn("2560x1440^", self.calls[1])
        self.assertEqual(self.calls[1][1], str(image) + "[0]")

    def test_hellwal_failure_propagates(self):
        self.calls = []
        image = self.folder / "image.png"
        image.touch()

        def run(cmd, **kwargs):
            if cmd[0] == "hellwal":
                self.assertEqual(cmd[-4:], ["--dark-offset", "0", "--bright-offset", "0"])
                raise RuntimeError("hellwal failed")
            return self.fake_run(cmd, **kwargs)

        with patch.object(setbg, "WALL_DIR", self.folder / "wall"), \
                patch.object(setbg, "run", side_effect=run):
            with self.assertRaisesRegex(RuntimeError, "hellwal failed"):
                setbg.apply_wallpaper(image, True)

    def test_hellwal_uses_mode_and_both_offsets(self):
        self.calls = []
        image = self.folder / "image.png"
        image.touch()
        with patch.object(setbg, "WALL_DIR", self.folder / "wall"), \
                patch.object(setbg, "run", side_effect=self.fake_run):
            setbg.apply_wallpaper(image, True, "light", 0.45, 0.2)
        self.assertEqual(self.calls[-1], [
            "hellwal", "-i", str(self.folder / "wall/wallpaper.png"),
            "--comfort-mode", "--light", "--dark-offset", "0.45",
            "--bright-offset", "0.2"
        ])

    def test_dark_offset_requires_hellwal_range_in_apply(self):
        image = self.folder / "image.png"
        image.touch()
        with self.assertRaisesRegex(ValueError, "offsets"):
            setbg.apply_wallpaper(image, True, "dark", 1.1)

    def test_concurrent_apply_is_rejected_before_desktop_commands(self):
        output = io.StringIO()
        with (self.folder / "apply.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with patch.object(setbg, "CACHE_DIR", self.folder), \
                    patch("sys.argv", ["setbg.py", "apply", "image.png"]), \
                    patch.object(setbg, "apply_wallpaper") as apply, \
                    contextlib.redirect_stdout(output):
                self.assertEqual(setbg.main(), 1)
            apply.assert_not_called()
        result = json.loads(output.getvalue())
        self.assertFalse(result["ok"])
        self.assertIn("still running", result["error"])

    def test_failed_blur_preserves_both_images_without_presenting_wallpaper(self):
        self.calls = []
        wall_dir = self.folder / "wall"
        wall_dir.mkdir()
        wallpaper = wall_dir / "wallpaper.png"
        wallpaper.write_bytes(b"old wallpaper")
        lockscreen = wall_dir / "lockscreen.png"
        lockscreen.write_bytes(b"old lockscreen")
        source = self.folder / "image.png"
        source.touch()

        def run(cmd, **kwargs):
            if "-blur" in cmd:
                raise RuntimeError("conversion failed")
            return self.fake_run(cmd, **kwargs)

        with patch.object(setbg, "WALL_DIR", wall_dir), \
                patch.object(setbg, "run", side_effect=run):
            with self.assertRaises(RuntimeError):
                setbg.apply_wallpaper(source)
        self.assertEqual(wallpaper.read_bytes(), b"old wallpaper")
        self.assertEqual(lockscreen.read_bytes(), b"old lockscreen")
        self.assertEqual([cmd[0] for cmd in self.calls], ["niri", "magick"])
        self.assertEqual(set(wall_dir.iterdir()), {wallpaper, lockscreen})


if __name__ == "__main__":
    unittest.main()
