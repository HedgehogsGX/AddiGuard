from flask import Blueprint, request, jsonify
from app.services.scan_service import ScanService

scan_bp = Blueprint('scan', __name__)
scan_service = ScanService()

@scan_bp.route('/scan', methods=['POST'])
def scan_image():
    if 'image' not in request.files:
        return jsonify({"error": "No image provided"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    try:
        # Read image bytes directly
        image_bytes = file.read()
        
        # Analyze
        results = scan_service.analyze_image(image_bytes)
        
        return jsonify({
            "status": "success",
            "additives_found": len(results),
            "results": results
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500
