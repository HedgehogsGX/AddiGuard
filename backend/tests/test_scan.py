import io
import json
import os
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from PIL import Image

from app import create_app
from app.migration import cleanup_legacy_additives
from app.routes import scan_service as default_service
from app.services.scan_service import ScanError, ScanService


def image_bytes(format="PNG"):
    image = Image.new("RGB", (32, 32), "white")
    output = io.BytesIO()
    image.save(output, format=format)
    return output.getvalue()


class FakeResponse:
    status_code = 200

    def __init__(self, content):
        self.content = content

    def json(self):
        return {"choices": [{"message": {"content": json.dumps(self.content)}}]}


class FakeSession:
    def __init__(self, content):
        self.content = content
        self.calls = []

    def post(self, *args, **kwargs):
        self.calls.append((args, kwargs))
        return FakeResponse(self.content)


class FailingSession:
    def __init__(self, error):
        self.error = error

    def post(self, *args, **kwargs):
        raise self.error


class ScanServiceTests(unittest.TestCase):
    def service(self, content):
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}, clear=False):
            return ScanService(FakeSession(content))

    def test_provider_data_and_chinese_name_are_returned_unchanged(self):
        content = {
            "readable_label": True,
            "results": [{
                "name": "柠檬酸",
                "risk_score": None,
                "traffic_light": None,
                "details": {
                    "name": "柠檬酸", "description": "API detail", "health_risk": None,
                    "usage_limit": None, "toxicity_level": None, "exposure_level": None,
                    "sensitivity_level": None, "cumulative_level": None,
                },
            }],
        }
        result = self.service(content).analyze_image(image_bytes())
        self.assertEqual(result["results"][0]["name"], "柠檬酸")
        self.assertEqual(result["results"][0]["details"]["description"], "API detail")

    def test_unreadable_label_is_not_empty_success(self):
        service = self.service({"readable_label": False, "results": []})
        with self.assertRaisesRegex(ScanError, "could not be read") as raised:
            service.analyze_image(image_bytes())
        self.assertEqual(raised.exception.status_code, 422)

    def test_invalid_schema_and_contradictory_risk_are_rejected(self):
        for content in (
            {"readable_label": True, "results": [{"name": "x", "risk_score": 2, "traffic_light": "Red", "details": {"name": "x"}}]},
            {"readable_label": True, "results": [{"name": "x", "risk_score": None, "traffic_light": "Green", "details": {"name": "x"}}]},
            {"readable_label": True, "results": [{"name": "x", "risk_score": 0.2, "traffic_light": [], "details": {"name": "x"}}]},
        ):
            with self.assertRaises(ScanError) as raised:
                self.service(content).analyze_image(image_bytes())
            self.assertEqual(raised.exception.status_code, 502)

    def test_bad_file_is_rejected_without_provider_call(self):
        with self.assertRaises(ScanError) as raised:
            self.service({}).analyze_image(b"not an image")
        self.assertEqual(raised.exception.status_code, 422)

    def test_missing_key_is_configuration_error(self):
        with patch.dict(os.environ, {"OPENAI_API_KEY": ""}, clear=False):
            service = ScanService(FakeSession({}))
        with self.assertRaises(ScanError) as raised:
            service.analyze_image(image_bytes())
        self.assertEqual(raised.exception.status_code, 503)

    def test_provider_timeout_and_http_failure_are_sanitized(self):
        import requests

        for failure, status in ((requests.Timeout(), 504), (requests.ConnectionError(), 502)):
            service = self.service({})
            service.session = FailingSession(failure)
            with self.assertRaises(ScanError) as raised:
                service.analyze_image(image_bytes())
            self.assertEqual(raised.exception.status_code, status)


class RouteTests(unittest.TestCase):
    def test_missing_file_is_bad_request(self):
        app = create_app()
        with app.test_client() as client:
            response = client.post("/api/scan")
        self.assertEqual(response.status_code, 400)


class MigrationTests(unittest.TestCase):
    def test_only_additives_table_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "legacy.db")
            with sqlite3.connect(path) as connection:
                connection.execute("CREATE TABLE additives (name TEXT)")
                connection.execute("INSERT INTO additives VALUES ('old')")
                connection.execute("CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)")
                connection.execute("INSERT INTO settings VALUES ('theme', 'dark')")
            self.assertTrue(cleanup_legacy_additives(path))
            with sqlite3.connect(path) as connection:
                tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                self.assertNotIn("additives", tables)
                self.assertEqual(connection.execute("SELECT value FROM settings WHERE key='theme'").fetchone()[0], "dark")

    def test_missing_database_is_not_created(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "missing.db")
            self.assertFalse(cleanup_legacy_additives(path))
            self.assertFalse(os.path.exists(path))


if __name__ == "__main__":
    unittest.main()
