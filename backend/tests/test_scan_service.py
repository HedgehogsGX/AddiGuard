from types import SimpleNamespace

import pytest

from app.models import Additive
from app.services.scan_service import ScanService


def make_additive(**levels):
    return SimpleNamespace(
        toxicity_level=levels.get("toxicity", 1),
        exposure_level=levels.get("exposure", 1),
        sensitivity_level=levels.get("sensitivity", 1),
        cumulative_level=levels.get("cumulative", 1),
    )


def test_risk_score_weights_factors():
    service = ScanService()
    assert service.calculate_risk_score(make_additive(toxicity=10, exposure=10, sensitivity=10, cumulative=10)) == 1.0
    assert service.calculate_risk_score(make_additive(toxicity=10)) == 0.46
    assert service.calculate_risk_score(make_additive(exposure=10)) == 0.37
    assert service.calculate_risk_score(make_additive(sensitivity=10)) == 0.28
    assert service.calculate_risk_score(make_additive(cumulative=10)) == 0.19


@pytest.mark.parametrize("score, expected", [
    (0.71, "Red"),
    (0.7, "Yellow"),
    (0.4, "Yellow"),
    (0.39, "Green"),
    (0, "Green"),
])
def test_traffic_light_thresholds(score, expected):
    assert ScanService().determine_traffic_light(score) == expected


def test_reader_is_not_loaded_on_construction():
    service = ScanService()
    assert "reader" not in service.__dict__


def test_analyze_image_matches_additives_in_ocr_text(app, monkeypatch):
    service = ScanService()
    monkeypatch.setattr(service, "extract_text", lambda _: ["INGREDIENTS:", "Pork, Salt,", "sodium nitrite", "(E250)"])

    results = service.analyze_image(b"irrelevant")

    assert [r["name"] for r in results] == ["Sodium Nitrite"]
    assert results[0]["risk_score"] == 0.83
    assert results[0]["traffic_light"] == "Red"
    assert results[0]["details"]["toxicity_level"] == 9


def test_analyze_image_tolerates_ocr_typos(app, monkeypatch):
    service = ScanService()
    monkeypatch.setattr(service, "extract_text", lambda _: ["contains", "S0dium Benzoate", "as preservative"])

    assert [r["name"] for r in service.analyze_image(b"irrelevant")] == ["Sodium Benzoate"]


def test_analyze_image_uses_additives_cache_instead_of_db(app, monkeypatch):
    service = ScanService()
    monkeypatch.setattr(service, "extract_text", lambda _: ["vitamin c"])
    cache = [Additive(name="Vitamin C", toxicity_level=1, exposure_level=1, sensitivity_level=1, cumulative_level=1)]

    results = service.analyze_image(b"irrelevant", additives_cache=cache)

    assert len(results) == 1
    assert results[0]["traffic_light"] == "Green"
