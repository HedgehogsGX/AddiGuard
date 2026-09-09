from io import BytesIO

import pytest
from PIL import Image

from app import create_app, db
from app.models import Additive


@pytest.fixture
def app():
    app = create_app({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
    })
    with app.app_context():
        db.session.add_all([
            Additive(name="Sodium Nitrite", description="Preservative.",
                     toxicity_level=9, exposure_level=8, sensitivity_level=7, cumulative_level=9),
            Additive(name="Sodium Benzoate", description="Preservative.",
                     toxicity_level=6, exposure_level=7, sensitivity_level=5, cumulative_level=4),
            Additive(name="Vitamin C", description="Antioxidant.",
                     toxicity_level=1, exposure_level=1, sensitivity_level=1, cumulative_level=1),
        ])
        db.session.commit()
        yield app


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def png_bytes():
    buffer = BytesIO()
    Image.new("RGB", (8, 8), "white").save(buffer, format="PNG")
    return buffer.getvalue()
