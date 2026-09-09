from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass

db = SQLAlchemy(model_class=Base)

class Additive(db.Model):
    __tablename__ = 'additives'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), unique=True, nullable=False)
    description = db.Column(db.Text, nullable=True)
    
    # Risk factors (1-10 scale)
    toxicity_level = db.Column(db.Integer, default=1) # toxicity_score
    exposure_level = db.Column(db.Integer, default=1) # exposure_risk
    sensitivity_level = db.Column(db.Integer, default=1) # sensitivity
    cumulative_level = db.Column(db.Integer, default=1) # cumulative_effect
    
    health_risk = db.Column(db.String(255), nullable=True) # Text description
    usage_limit = db.Column(db.String(255), nullable=True)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'toxicity_level': self.toxicity_level,
            'exposure_level': self.exposure_level,
            'sensitivity_level': self.sensitivity_level,
            'cumulative_level': self.cumulative_level,
            'health_risk': self.health_risk,
            'usage_limit': self.usage_limit
        }
