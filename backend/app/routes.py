from io import BytesIO

from flask import Blueprint, current_app, jsonify, request
from PIL import Image, UnidentifiedImageError

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
    except (UnidentifiedImageError, OSError):
        return jsonify({"error": "Uploaded file is not a valid image"}), 400

    try:
        results = scan_service.analyze_image(image_bytes)
    except Exception:
        current_app.logger.exception("Image analysis failed")
        return jsonify({"error": "Image analysis failed"}), 500

    overall_risk_score = max((r["risk_score"] for r in results), default=0)
    return jsonify({
        "status": "success",
        "additives_found": len(results),
        "overall_risk_score": overall_risk_score,
        "overall_traffic_light": scan_service.determine_traffic_light(overall_risk_score),
        "results": results
    })
