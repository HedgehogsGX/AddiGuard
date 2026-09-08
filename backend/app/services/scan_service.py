"""Vision-provider backed ingredient analysis."""

import base64
import io
import json
import math
import os
import re
from typing import Any

import requests
from PIL import Image, ImageFile, UnidentifiedImageError
from PIL.Image import DecompressionBombError


ImageFile.LOAD_TRUNCATED_IMAGES = False

MAX_IMAGE_BYTES = 8 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000
ALLOWED_FORMATS = {"JPEG": "image/jpeg", "PNG": "image/png", "WEBP": "image/webp"}
TRAFFIC_LIGHTS = {"Red", "Yellow", "Green"}
DETAIL_FIELDS = (
    "name",
    "description",
    "health_risk",
    "usage_limit",
    "toxicity_level",
    "exposure_level",
    "sensitivity_level",
    "cumulative_level",
)


class ScanError(Exception):
    def __init__(self, message: str, status_code: int):
        super().__init__(message)
        self.status_code = status_code


class ScanService:
    def __init__(self, session: Any = requests):
        self.session = session
        self.api_key = os.environ.get("OPENAI_API_KEY", "").strip()
        self.base_url = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1").strip().rstrip("/")
        self.model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini").strip()
        try:
            self.timeout = float(os.environ.get("OPENAI_TIMEOUT_SECONDS", "45"))
        except ValueError:
            self.timeout = 0
        prompt_path = os.path.join(
            os.path.dirname(os.path.dirname(__file__)), "prompts", "analyze_additives.txt"
        )
        with open(prompt_path, encoding="utf-8") as prompt_file:
            self.system_prompt = prompt_file.read()

    def analyze_image(self, image_bytes: bytes) -> dict[str, Any]:
        mime_type = self._validate_image(image_bytes)
        if not self.api_key or not self.base_url or not self.model or not math.isfinite(self.timeout) or self.timeout <= 0:
            raise ScanError("Vision analysis is not configured on the server.", 503)

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": self.system_prompt},
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "Read the ingredient label in this image and return the requested JSON.",
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{base64.b64encode(image_bytes).decode('ascii')}"
                            },
                        },
                    ],
                },
            ],
            "response_format": {"type": "json_object"},
        }
        try:
            response = self.session.post(
                f"{self.base_url}/chat/completions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json=payload,
                timeout=self.timeout,
            )
        except requests.Timeout as exc:
            raise ScanError("Vision provider timed out. Please try again.", 504) from exc
        except requests.RequestException as exc:
            raise ScanError("Vision provider is unavailable. Please try again.", 502) from exc

        if not 200 <= response.status_code < 300:
            raise ScanError("Vision provider returned an unavailable response.", 502)
        try:
            provider_response = response.json()
            content = provider_response["choices"][0]["message"]["content"]
            parsed = self._parse_content(content)
        except (ValueError, KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
            raise ScanError("Vision provider returned invalid analysis data.", 502) from exc
        return self._validate_analysis(parsed)

    @staticmethod
    def _validate_image(image_bytes: bytes) -> str:
        if not image_bytes:
            raise ScanError("The uploaded image is empty.", 422)
        if len(image_bytes) > MAX_IMAGE_BYTES:
            raise ScanError("The image exceeds the 8 MB upload limit.", 413)
        try:
            with Image.open(io.BytesIO(image_bytes)) as image:
                if image.format not in ALLOWED_FORMATS:
                    raise ScanError("Use a JPEG, PNG, or WebP image.", 415)
                width, height = image.size
                if width <= 0 or height <= 0 or width * height > MAX_IMAGE_PIXELS:
                    raise ScanError("The image dimensions are not supported.", 422)
                image.verify()
        except ScanError:
            raise
        except (DecompressionBombError, UnidentifiedImageError, OSError, ValueError):
            raise ScanError("The uploaded file is not a readable image.", 422)
        return ALLOWED_FORMATS[image.format]

    @staticmethod
    def _parse_content(content: Any) -> dict[str, Any]:
        if isinstance(content, list):
            content = "".join(
                part.get("text", "") for part in content if isinstance(part, dict)
            )
        if not isinstance(content, str):
            raise ValueError("content is not text")
        content = content.strip()
        fenced = re.fullmatch(r"```(?:json)?\s*(.*?)\s*```", content, re.DOTALL | re.IGNORECASE)
        if fenced:
            content = fenced.group(1)
        parsed = json.loads(content)
        if not isinstance(parsed, dict):
            raise ValueError("analysis is not an object")
        return parsed

    @classmethod
    def _validate_analysis(cls, value: dict[str, Any]) -> dict[str, Any]:
        readable = value.get("readable_label")
        if not isinstance(readable, bool):
            raise ScanError("Vision provider returned invalid analysis data.", 502)
        if not readable:
            raise ScanError(
                "The ingredient label could not be read. Please retake the photo clearly.", 422
            )
        results = value.get("results")
        if not isinstance(results, list):
            raise ScanError("Vision provider returned invalid analysis data.", 502)
        validated = []
        for result in results:
            if not isinstance(result, dict) or not isinstance(result.get("name"), str) or not result["name"].strip():
                raise ScanError("Vision provider returned invalid analysis data.", 502)
            score = result.get("risk_score")
            traffic = result.get("traffic_light")
            if score is not None and (isinstance(score, bool) or not isinstance(score, (int, float)) or not math.isfinite(score) or not 0 <= score <= 1):
                raise ScanError("Vision provider returned invalid analysis data.", 502)
            if traffic is not None and (not isinstance(traffic, str) or traffic not in TRAFFIC_LIGHTS):
                raise ScanError("Vision provider returned invalid analysis data.", 502)
            if (score is None) != (traffic is None) or (score is not None and not cls._traffic_matches(score, traffic)):
                raise ScanError("Vision provider returned contradictory risk data.", 502)
            details = result.get("details")
            if not isinstance(details, dict) or not isinstance(details.get("name"), str):
                raise ScanError("Vision provider returned invalid analysis data.", 502)
            clean_details = {"name": details["name"]}
            for field in DETAIL_FIELDS[1:]:
                field_value = details.get(field)
                if field_value is not None:
                    if field.endswith("_level"):
                        if isinstance(field_value, bool) or not isinstance(field_value, int) or not 1 <= field_value <= 10:
                            raise ScanError("Vision provider returned invalid analysis data.", 502)
                    elif not isinstance(field_value, str):
                        raise ScanError("Vision provider returned invalid analysis data.", 502)
                clean_details[field] = field_value
            validated.append({"name": result["name"].strip(), "risk_score": score, "traffic_light": traffic, "details": clean_details})
        return {"status": "success", "additives_found": len(validated), "results": validated}

    @staticmethod
    def _traffic_matches(score: float, traffic: str) -> bool:
        return (traffic == "Red" and score > 0.7) or (traffic == "Yellow" and 0.4 <= score <= 0.7) or (traffic == "Green" and score < 0.4)
