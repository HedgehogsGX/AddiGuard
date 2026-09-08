import os

from flask import Flask

from app.migration import cleanup_legacy_additives
from app.routes import scan_bp


def create_app():
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 8 * 1024 * 1024
    cleanup_legacy_additives(os.environ.get("LEGACY_DB_PATH"))
    app.register_blueprint(scan_bp, url_prefix="/api")

    @app.errorhandler(413)
    def request_too_large(_error):
        return {"error": "The image exceeds the 8 MB upload limit."}, 413

    @app.get("/")
    def health():
        return {"status": "ok"}

    return app
