from app import create_app, db
from app.models import Additive

def seed_database():
    app = create_app()
    with app.app_context():
        # Clear existing data
        db.drop_all()
        db.create_all()

        additives = [
            # High Risk (Red)
            Additive(
                name="Sodium Nitrite",
                e_number="E250", aliases=["sodium nitrite"],
                description="Preservative used in cured meats.",
                toxicity_level=9,
                exposure_level=8,
                sensitivity_level=7,
                cumulative_level=9,
                health_risk="Linked to colorectal cancer; Carcinogen.",
                usage_limit="Strictly limited in meats."
            ),
            # Medium Risk (Yellow)
            Additive(
                name="Sodium Benzoate",
                e_number="E211", aliases=["sodium benzoate"],
                description="Preservative in acidic foods.",
                toxicity_level=6,
                exposure_level=7,
                sensitivity_level=5,
                cumulative_level=4,
                health_risk="May cause hyperactivity; can form benzene.",
                usage_limit="Common in sodas and pickles."
            ),
            # Low Risk (Green)
            Additive(
                name="Vitamin C",
                e_number="E300", aliases=["vitamin c", "ascorbic acid"],
                description="Ascorbic Acid, antioxidant.",
                toxicity_level=1,
                exposure_level=1,
                sensitivity_level=1,
                cumulative_level=1,
                health_risk="Safe; beneficial.",
                usage_limit="None."
            ),
            # Additional Dummy Data
            Additive(
                name="Aspartame",
                e_number="E951", aliases=["aspartame"],
                description="Artificial sweetener.",
                toxicity_level=5,
                exposure_level=9,
                sensitivity_level=6,
                cumulative_level=5,
                health_risk="Headaches in sensitive individuals.",
                usage_limit="ADI 50mg/kg."
            ),
            Additive(
                name="Monosodium Glutamate",
                e_number="E621", aliases=["monosodium glutamate", "msg"],
                description="Flavor enhancer (MSG).",
                toxicity_level=4,
                exposure_level=8,
                sensitivity_level=8,
                cumulative_level=2,
                health_risk="MSG symptom complex in some people.",
                usage_limit="GRAS (Generally Recognized As Safe)."
            )
        ]

        db.session.add_all(additives)
        db.session.commit()
        print("Database seeded successfully with 5 additives.")

if __name__ == '__main__':
    seed_database()
