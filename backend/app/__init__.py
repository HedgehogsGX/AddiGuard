from flask import Flask
from app.models import db
from app.routes import scan_bp

def create_app():
    app = Flask(__name__)
    
    # Configuration
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///addiguard.db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    # Initialize extensions
    db.init_app(app)
    
    # Register Blueprints
    app.register_blueprint(scan_bp, url_prefix='/api')

    # Create tables
    with app.app_context():
        db.create_all()

    return app
