from io import BytesIO

from flask import Blueprint, current_app, jsonify, request
from PIL import Image

from app.services.scan_service import ScanService

scan_bp = Blueprint('scan', __name__)
scan_service = ScanService()


@scan_bp.route('/scan', methods=['POST'])
def scan_image():
    file = request.files.get('image')
    if file is None or file.filename == '':
        return jsonify({"error": "No image provided"}), 400

    image_bytes = file.read()
    try:
        Image.open(BytesIO(image_bytes)).verify()
    except Exception:
        return jsonify({"error": "Uploaded file is not a valid image"}), 400

    try:
        results = scan_service.analyze_image(image_bytes)
    except Exception:
        current_app.logger.exception("Image analysis failed")
        return jsonify({"error": "Image analysis failed"}), 500

    rated_scores = [r["risk_score"] for r in results if r["risk_score"] is not None]
    overall_risk_score = max(rated_scores) if rated_scores else (None if results else 0)
    return jsonify({
        "status": "success",
        "additives_found": len(results),
        "overall_risk_score": overall_risk_score,
        "overall_traffic_light": scan_service.determine_traffic_light(overall_risk_score),
        "results": results
    })
