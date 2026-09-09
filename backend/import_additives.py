"""Upsert English E-number entries from the bundled Open Food Facts taxonomy."""
import argparse
import re
from pathlib import Path

from app import create_app, db
from app.models import Additive
from app.services.scan_service import ScanService, normalize_e_number


DEFAULT_SOURCE = Path(__file__).parent / "data" / "additives.txt"


def parse_taxonomy(text):
    records = {}
    for line in text.splitlines():
        if not line.startswith("en:"):
            continue
        values = [value.strip().replace(r"\,", ",") for value in re.split(r"(?<!\\),", line[3:])]
        e_number = normalize_e_number(values[0])
        if e_number is None:
            continue
        name = values[1] if len(values) > 1 and values[1] else e_number
        record = records.setdefault(e_number, {"e_number": e_number, "name": name, "aliases": set()})
        record["aliases"].update(value.lower() for value in values[1:] if value)
    return [{**record, "aliases": sorted(record["aliases"])} for record in records.values()]


def import_additives(source=DEFAULT_SOURCE):
    records = parse_taxonomy(Path(source).read_text(encoding="utf-8"))
    additives = Additive.query.all()
    by_code = {additive.e_number: additive for additive in additives if additive.e_number}
    by_name = {additive.name.lower(): additive for additive in additives}
    for record in records:
        code, name = record["e_number"], record["name"]
        additive = by_code.get(code)
        if additive is None:
            candidate = by_name.get(name.lower())
            if candidate is not None and candidate.e_number is None:
                additive = candidate
            else:
                if candidate is not None:
                    name = f"{name} ({code})"
                additive = Additive(name=name)
                db.session.add(additive)
                by_name[name.lower()] = additive
            additive.e_number = code
            by_code[code] = additive
        additive.aliases = sorted({alias.lower() for alias in (additive.aliases or [])} | set(record["aliases"]))
    db.session.commit()
    ScanService.refresh_alias_index()
    return len(records)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", default=DEFAULT_SOURCE, help="Path to an OFF raw taxonomy snapshot")
    args = parser.parse_args()
    app = create_app()
    with app.app_context():
        print(f"Imported {import_additives(args.source)} additives")
