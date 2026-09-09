from pathlib import Path

from app import create_app
from app.models import Additive, db
from app.services.scan_service import ScanService, match_additives
from import_additives import DEFAULT_SOURCE, import_additives, parse_taxonomy
from seed import seed_database


def test_parser_handles_english_synonyms_subtypes_and_escaped_commas():
    assert parse_taxonomy(r"""fr: E250, nitrite de sodium
en: E250, Sodium nitrite, NaNO2
en: E150A, Plain caramel
en: E101(i), Riboflavin, Vitamin B2
en: E621, Monosodium glutamate, L-Glutamic acid\, monosodium salt
en: E571
en: E14XX, Modified starch
en: Organic acids
""") == [
        {"e_number": "E250", "name": "Sodium nitrite", "aliases": ["nano2", "sodium nitrite"]},
        {"e_number": "E150a", "name": "Plain caramel", "aliases": ["plain caramel"]},
        {"e_number": "E101(i)", "name": "Riboflavin", "aliases": ["riboflavin", "vitamin b2"]},
        {"e_number": "E621", "name": "Monosodium glutamate", "aliases": ["l-glutamic acid, monosodium salt", "monosodium glutamate"]},
        {"e_number": "E571", "name": "E571", "aliases": []},
    ]


def test_full_snapshot_upsert_preserves_all_seeded_ratings_and_is_offline(tmp_path, monkeypatch):
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{tmp_path / 'additives.db'}")
    seed_database()
    app = create_app()
    with app.app_context():
        seeded = {a.e_number: a.to_dict() for a in Additive.query.all()}
        assert len(seeded) == 5
        first_count = import_additives()
        first = {a.e_number: a.to_dict() for a in Additive.query.all()}
        assert first_count > 600
        assert len(first) == first_count
        assert import_additives() == first_count
        assert {a.e_number: a.to_dict() for a in Additive.query.all()} == first
        for code, original in seeded.items():
            for field in ("id", "name", "toxicity_level", "exposure_level", "sensitivity_level", "cumulative_level", "description", "health_risk", "usage_limit"):
                assert first[code][field] == original[field]
        for code, data in first.items():
            assert all(alias == alias.lower() for alias in data["aliases"])
            if code not in seeded:
                assert all(data[field] is None for field in ("toxicity_level", "exposure_level", "sensitivity_level", "cumulative_level"))
        assert first["E101"]["id"] != first["E101(i)"]["id"]
        assert "ascorbic acid" in first["E300"]["aliases"]
        assert "msg" in first["E621"]["aliases"]


def test_import_refreshes_existing_aliases_without_changing_curation(app, tmp_path, monkeypatch):
    service = ScanService()
    monkeypatch.setattr(service, "extract_text", lambda _: ["Sodium nitrite"])
    service.analyze_image(b"")
    source = tmp_path / "taxonomy.txt"
    source.write_text("en: E250, Sodium nitrite, curing additive\n", encoding="utf-8")
    original = Additive.query.filter_by(name="Sodium Nitrite").one().to_dict()
    import_additives(source)
    assert "additive_alias_index" not in app.extensions
    updated = Additive.query.filter_by(e_number="E250").one()
    assert updated.id == original["id"]
    assert updated.toxicity_level == original["toxicity_level"]
    monkeypatch.setattr(service, "extract_text", lambda _: ["curing additive"])
    assert service.analyze_image(b"")[0]["matched_text"] == "curing additive"


def test_full_taxonomy_matching_does_not_confuse_nearby_chemicals(app):
    import_additives()
    additives = {a.id: a for a in Additive.query.all()}
    index = ScanService._build_index(additives)
    labels = [
        ("Water, sugar, flour, salt. 250g 621kJ", set()),
        ("Sodium nitrite, ascorbic acid", {"E250", "E300"}),
        ("Sodium nitrate, isoascorbic acid", {"E251", "E315"}),
        ("E 211, E-330, E150a", {"E211", "E330", "E150a"}),
        ("flavour enhancer (621)", {"E621"}),
        ("S0dium benz0ate, asc0rbic acid", {"E211", "E300"}),
        ("msgpack, messages, 250 621", set()),
        ("E101(i)", {"E101(i)"}),
    ]
    for label, expected in labels:
        matches = match_additives([label], index)
        assert {additives[key].e_number for key in matches} == expected, label


def test_snapshot_checksum_is_documented():
    import hashlib

    checksum = hashlib.sha256(DEFAULT_SOURCE.read_bytes()).hexdigest()
    assert checksum in (Path(DEFAULT_SOURCE).parent / "PROVENANCE.md").read_text()
