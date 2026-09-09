from io import BytesIO

import pytest

from app import routes
from app.models import Additive, db


@pytest.mark.parametrize("label, score, light, count", [
    ("E330", None, "Unrated", 1),
    ("E330 Sodium Nitrite", 0.83, "Red", 2),
    ("E330 Vitamin C", 0.1, "Green", 2),
])
def test_overall_excludes_unrated_detections(app, client, png_bytes, monkeypatch, label, score, light, count):
    db.session.add(Additive(name="Citric acid", e_number="E330", aliases=["citric acid"]))
    db.session.commit()
    monkeypatch.setattr(routes.scan_service, "extract_text", lambda _: [label])
    response = client.post("/api/scan", data={"image": (BytesIO(png_bytes), "scan.png")})
    assert response.status_code == 200
    body = response.get_json()
    assert body["overall_risk_score"] == score
    assert body["overall_traffic_light"] == light
    assert body["additives_found"] == count
    unrated = next(result for result in body["results"] if result["name"] == "Citric acid")
    assert unrated["risk_score"] is None
    assert unrated["traffic_light"] == "Unrated"
    assert unrated["matched_text"] == "e330"
    assert unrated["details"]["aliases"] == ["citric acid"]
    assert unrated["details"]["e_number"] == "E330"
