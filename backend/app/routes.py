from flask import Blueprint, current_app, jsonify, request

from app.services.scan_service import ScanError, ScanService

scan_bp = Blueprint("scan", __name__)
scan_service = ScanService()


@scan_bp.route("/scan", methods=["POST"])
def scan_image():
    if "image" not in request.files:
        return jsonify({"error": "No image provided."}), 400
    file = request.files["image"]
    if not file.filename:
        return jsonify({"error": "No selected file."}), 400
    try:
        return jsonify(scan_service.analyze_image(file.read()))
    except ScanError as error:
        current_app.logger.warning("Scan failed: HTTP %s; %s", error.status_code, error)
        return jsonify({"error": str(error)}), error.status_code
    except Exception as error:
        current_app.logger.error("Unexpected scan failure (%s).", type(error).__name__)
        return jsonify({"error": "Scan service unavailable. Please try again."}), 502
