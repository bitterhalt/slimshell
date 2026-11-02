"""Offline weather data/cache tests; no real HTTP or desktop processes."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import importlib.util

spec = importlib.util.spec_from_file_location("weather", Path(__file__).resolve().parents[2] / "weather/weather.py")
weather = importlib.util.module_from_spec(spec)
spec.loader.exec_module(weather)


def sample():
    return {
        "_key": weather.CONFIG_KEY, "_place": "Example",
        "current": {"temperature_2m": 12.4, "apparent_temperature": 10.2,
                    "weather_code": 0, "is_day": 1, "relative_humidity_2m": 60,
                    "wind_speed_10m": 15.2, "wind_direction_10m": 315,
                    "visibility": 10000, "uv_index": None},
        "daily": {"time": ["2026-11-01"], "weather_code": [3],
                  "temperature_2m_max": [13.2], "temperature_2m_min": [4.8],
                  "precipitation_probability_max": [None],
                  "sunrise": ["2026-11-01T07:00"], "sunset": ["2026-11-01T17:00"]},
    }


class WeatherTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.cache = Path(self.directory.name) / "weather.json"
        self.patcher = patch.object(weather, "CACHE_FILE", self.cache)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def test_format_conditions_and_forecast(self):
        result = weather.format_weather(sample())
        self.assertEqual(result["temperature"], 12)
        self.assertEqual(result["windDirection"], "NW")
        self.assertEqual(result["sunrise"], "07:00")
        self.assertEqual(result["forecast"][0]["rain"], 0)
        self.assertEqual(result["uv"], 0)
        self.assertEqual(weather.describe(0, False)[1], "🌙")

    def test_fresh_cache_does_not_fetch(self):
        self.cache.write_text(json.dumps(sample()))
        with patch.object(weather, "fetch_weather") as fetch:
            self.assertIsNotNone(weather.load_weather())
            fetch.assert_not_called()

    def test_forced_refresh_fetches(self):
        self.cache.write_text(json.dumps(sample()))
        with patch.object(weather, "fetch_weather", return_value=sample()) as fetch:
            weather.load_weather(True)
            fetch.assert_called_once()

    def test_failed_refresh_reuses_cache(self):
        self.cache.write_text(json.dumps(sample()))
        with patch.object(weather, "fetch_weather", side_effect=OSError):
            self.assertEqual(weather.load_weather(True)["_place"], "Example")

    def test_invalid_and_other_location_cache_are_ignored(self):
        for data in ({"_key": weather.CONFIG_KEY}, {**sample(), "_key": "different"}):
            self.cache.write_text(json.dumps(data))
            self.assertIsNone(weather.read_cache())

    def test_explicit_coordinates_avoid_geolocation(self):
        with patch.multiple(weather, LAT="60", LON="25", NAME="Example"), \
                patch.object(weather, "get_json") as get:
            self.assertEqual(weather.resolve_location(), (60, 25, "Example"))
            get.assert_not_called()

    def test_fetch_writes_validated_cache(self):
        with patch.object(weather, "resolve_location", return_value=(60, 25, "Example")), \
                patch.object(weather, "get_json", return_value=sample()):
            weather.fetch_weather()
        self.assertEqual(json.loads(self.cache.read_text())["_place"], "Example")

    def test_unavailable_response_is_json(self):
        output = io.StringIO()
        with patch.object(weather, "load_weather", return_value=None), contextlib.redirect_stdout(output):
            weather.main()
        self.assertFalse(json.loads(output.getvalue())["available"])
