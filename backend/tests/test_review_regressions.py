import io
import os
import unittest
from unittest.mock import Mock, patch

from test_scan import FakeSession, image_bytes

from app import create_app
from app.routes import scan_service
from app.services.scan_service import ScanError, ScanService


class ApiContractTests(unittest.TestCase):
    def service(self, name):
        content = {
            "readable_label": True,
            "results": [{
                "name": "provider ingredient",
                "risk_score": None,
                "traffic_light": None,
                "details": {"name": name},
            }],
        }
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}):
            return ScanService(FakeSession(content))

    def test_empty_detail_names_fall_back_to_the_additive_name(self):
        for name in ("", " \t\n"):
            with self.subTest(name=name):
                result = self.service(name).analyze_image(image_bytes())
                self.assertEqual(result["results"][0]["details"]["name"], "provider ingredient")

    def test_detail_names_are_trimmed(self):
        result = self.service(" provider ingredient ").analyze_image(image_bytes())
        self.assertEqual(result["results"][0]["details"]["name"], "provider ingredient")

    def test_provider_status_logged_without_response_body(self):
        service = self.service("provider ingredient")
        service.session = Mock()
        service.session.post.return_value = Mock(
            status_code=401, text="private-test-content"
        )
        with self.assertLogs("app.services.scan_service", level="WARNING") as logs:
            with self.assertRaises(ScanError) as raised:
                service.analyze_image(image_bytes())
        self.assertEqual(raised.exception.status_code, 502)
        self.assertIn("HTTP 401", " ".join(logs.output))
        self.assertNotIn("private-test-content", " ".join(logs.output))
        self.assertNotIn("test-key", " ".join(logs.output))

    def test_unexpected_failure_logs_type_without_exception_details(self):
        app = create_app()
        with patch.object(
            scan_service, "analyze_image", side_effect=RuntimeError("private-test-content")
        ):
            with self.assertLogs(app.logger, level="ERROR") as logs:
                with app.test_client() as client:
                    response = client.post(
                        "/api/scan",
                        data={"image": (io.BytesIO(image_bytes()), "label.png")},
                    )
        self.assertEqual(response.status_code, 502)
        self.assertIn("RuntimeError", " ".join(logs.output))
        self.assertNotIn("private-test-content", " ".join(logs.output))
        self.assertNotIn("private-test-content", response.get_data(as_text=True))


if __name__ == "__main__":
    unittest.main()
