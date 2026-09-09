from io import BytesIO

from app import routes


def post_scan(client, payload, filename="scan.jpg"):
    return client.post("/api/scan", data={"image": (BytesIO(payload), filename)}, content_type="multipart/form-data")


def test_scan_without_image_field_returns_400(client):
    response = client.post("/api/scan", data={}, content_type="multipart/form-data")
    assert response.status_code == 400
    assert response.get_json() == {"error": "No image provided"}


def test_scan_with_empty_filename_returns_400(client):
    response = post_scan(client, b"", filename="")
    assert response.status_code == 400
    assert response.get_json() == {"error": "No image provided"}


def test_scan_rejects_non_image_payload(client):
    response = post_scan(client, b"this is not an image")
    assert response.status_code == 400
    assert response.get_json() == {"error": "Uploaded file is not a valid image"}


def test_scan_rejects_oversized_upload_with_json(client, app):
    app.config["MAX_CONTENT_LENGTH"] = 1024
    response = post_scan(client, b"x" * 2048)
    assert response.status_code == 413
    assert "error" in response.get_json()


def test_scan_returns_matches_and_overall_risk(client, png_bytes, monkeypatch):
    monkeypatch.setattr(routes.scan_service, "extract_text", lambda _: ["Sodium Nitrite,", "Vitamin C"])

    response = post_scan(client, png_bytes)

    assert response.status_code == 200
    body = response.get_json()
    assert body["status"] == "success"
    assert body["additives_found"] == 2
    assert body["overall_risk_score"] == 0.83
    assert body["overall_traffic_light"] == "Red"
    assert {r["name"]: r["traffic_light"] for r in body["results"]} == {"Sodium Nitrite": "Red", "Vitamin C": "Green"}


def test_scan_with_no_matches_is_green(client, png_bytes, monkeypatch):
    monkeypatch.setattr(routes.scan_service, "extract_text", lambda _: ["Water", "Sugar"])

    body = post_scan(client, png_bytes).get_json()

    assert body["additives_found"] == 0
    assert body["overall_risk_score"] == 0
    assert body["overall_traffic_light"] == "Green"
    assert body["results"] == []


def test_scan_hides_internal_errors(client, png_bytes, monkeypatch):
    def explode(_):
        raise RuntimeError("secret internal detail")

    monkeypatch.setattr(routes.scan_service, "extract_text", explode)

    response = post_scan(client, png_bytes)

    assert response.status_code == 500
    assert response.get_json() == {"error": "Image analysis failed"}


def test_unknown_route_returns_json_404(client):
    response = client.get("/api/nope")
    assert response.status_code == 404
    assert "error" in response.get_json()


def test_cors_header_present_on_api(client, png_bytes, monkeypatch):
    monkeypatch.setattr(routes.scan_service, "extract_text", lambda _: [])
    response = post_scan(client, png_bytes)
    assert response.headers["Access-Control-Allow-Origin"] == "*"
