import pytest

from app.models import Additive, db
from app.services.scan_service import ScanService, match_additives, normalize_e_number, normalize_phrase


@pytest.fixture
def label_additives():
    return [
        Additive(name="Sodium Nitrite", e_number="E250", aliases=["sodium nitrite"]),
        Additive(name="Sodium Benzoate", e_number="E211", aliases=["sodium benzoate"]),
        Additive(name="Vitamin C", e_number="E300", aliases=["ascorbic acid"]),
        Additive(name="Monosodium Glutamate", e_number="E621", aliases=["msg"]),
        Additive(name="Citric acid", e_number="E330", aliases=[]),
        Additive(name="Plain caramel", e_number="E150a", aliases=[]),
        Additive(name="Sodium nitrate", e_number="E251", aliases=[]),
        Additive(name="Isoascorbic acid", e_number="E315", aliases=[]),
    ]


@pytest.mark.parametrize("text, codes", [
    ("Ingredients: pork, salt, sodium nitrite, antioxidant ascorbic acid.", {"E250", "E300"}),
    ("Carbonated water, sugar, E 211, E-330, colour E150a.", {"E211", "E330", "E150a"}),
    ("Sodium nitrite (E250), MSG, flavour enhancer (621), ascorbic acid.", {"E250", "E621", "E300"}),
    ("Ingredients: water, sugar, flour, salt. 250 g. Energy 621 kJ.", set()),
    ("S0dium benzoate; asc0rbic acid; monosodium glutamte", {"E211", "E300", "E621"}),
    ("amsgword, messages, msgpack", set()),
    ("Preservatives (250, 211); flavour enhancer (621); antioxidant: 300", {"E250", "E211", "E621", "E300"}),
    ("Flavour 621, agent 250, regulator 330, 150a", set()),
    ("E250a, E150, XE211, 1E330, E6210", set()),
    ("Sodium nitrate, isoascorbic acid", {"E251", "E315"}),
])
def test_realistic_labels_are_matched_without_ocr_or_database(label_additives, text, codes):
    additives = dict(enumerate(label_additives))
    matches = match_additives([text], ScanService._build_index(additives))
    assert {additives[key].e_number for key in matches} == codes
    assert all(matches.values())


def test_normalization_preserves_codes_and_normalizes_safe_noise():
    assert normalize_e_number(" e-150A ") == "E150a"
    assert normalize_e_number("250") is None
    assert normalize_phrase("S0dium, asc0rbic 250 1000 E250") == "sodium ascorbic 250 1000 e250"


def test_every_missing_risk_factor_is_unrated():
    service = ScanService()
    for field in ("toxicity_level", "exposure_level", "sensitivity_level", "cumulative_level"):
        additive = Additive(toxicity_level=1, exposure_level=1, sensitivity_level=1, cumulative_level=1)
        setattr(additive, field, None)
        assert service.calculate_risk_score(additive) is None
    assert service.determine_traffic_light(None) == "Unrated"


def test_index_reused_and_new_rows_refresh_it(app, monkeypatch):
    service = ScanService()
    monkeypatch.setattr(service, "extract_text", lambda _: ["Sodium nitrite"])
    service.analyze_image(b"")
    index = app.extensions["additive_alias_index"][1]
    service.analyze_image(b"")
    assert app.extensions["additive_alias_index"][1] is index
    db.session.add(Additive(name="Citric acid", e_number="E330"))
    db.session.commit()
    monkeypatch.setattr(service, "extract_text", lambda _: ["E330"])
    assert service.analyze_image(b"")[0]["traffic_light"] == "Unrated"
    assert app.extensions["additive_alias_index"][1] is not index


def test_explicit_refresh_picks_up_alias_edits_and_current_risk(app, monkeypatch):
    service = ScanService()
    monkeypatch.setattr(service, "extract_text", lambda _: ["Sodium nitrite"])
    service.analyze_image(b"")
    additive = Additive.query.filter_by(name="Sodium Nitrite").one()
    additive.aliases = ["curing additive"]
    additive.toxicity_level = None
    db.session.commit()
    ScanService.refresh_alias_index()
    monkeypatch.setattr(service, "extract_text", lambda _: ["curing additive"])
    result = service.analyze_image(b"")[0]
    assert result["matched_text"] == "curing additive"
    assert result["risk_score"] is None
