import re
import threading
from collections import defaultdict

from flask import current_app
from sqlalchemy import func, select
from thefuzz import fuzz

from app.models import Additive, db


_CODE_BODY = r"\d{3,4}[a-z]?(?:\s*\(\s*[ivx]+\s*\))?"
_E_NUMBER = re.compile(rf"\be\s*[-–—]?\s*({_CODE_BODY})(?!\w)", re.IGNORECASE)
_CLASS_CODES = re.compile(
    r"\b(?:preservatives?|flavou?r enhancers?|colou?rs?|emulsifiers?|antioxidants?|"
    r"sweeteners?|stabili[sz]ers?|thickeners?|acidity regulators?|raising agents?)"
    rf"\s*[:(\[]?\s*({_CODE_BODY}(?:\s*[,;/]\s*{_CODE_BODY})*)(?!\w)",
    re.IGNORECASE,
)


def normalize_e_number(value):
    if not value:
        return None
    match = _E_NUMBER.fullmatch(str(value).strip())
    return "E" + re.sub(r"\s+", "", match.group(1)).lower() if match else None


def normalize_phrase(value):
    text = str(value).lower()
    text = re.sub(r"\b[a-z0]+\b", lambda m: m[0].replace("0", "o") if re.search(r"[a-z]", m[0]) else m[0], text)
    return " ".join(re.findall(r"[^\W_]+", text))


def match_additives(extracted_text, index):
    raw = " ".join(extracted_text)
    aliases, codes, fuzzy, widths = index
    found = {}
    for match in _E_NUMBER.finditer(raw):
        key = codes.get(normalize_e_number(match[0]))
        if key is not None:
            found.setdefault(key, normalize_phrase(match[0]))
    for match in _CLASS_CODES.finditer(raw):
        for code in re.findall(_CODE_BODY, match[1], re.IGNORECASE):
            key = codes.get(normalize_e_number(f"E{code}"))
            if key is not None:
                found.setdefault(key, code.lower())

    tokens = normalize_phrase(_E_NUMBER.sub(" ", raw)).split()
    occupied = set()
    for width in widths:
        for start in range(len(tokens) - width + 1):
            span = set(range(start, start + width))
            if occupied & span:
                continue
            phrase = " ".join(tokens[start:start + width])
            if phrase in aliases:
                for key in aliases[phrase]:
                    found.setdefault(key, phrase)
                occupied.update(span)

    for width in widths:
        for start in range(len(tokens) - width + 1):
            span = set(range(start, start + width))
            if occupied & span:
                continue
            phrase = " ".join(tokens[start:start + width])
            # A lone word gets a stricter bar: one substitution in a word under twelve letters
            # scores at most 90, which is exactly where everyday label words collide with
            # additive names ("carbonated" vs "carbonates"). Multi-word phrases carry enough
            # context to keep the looser threshold for OCR slips.
            threshold = 91 if width == 1 else 88
            best_score, best_keys = threshold - 1, set()
            for alias in fuzzy.get((width, phrase[0]), []):
                if abs(len(alias) - len(phrase)) > max(1, len(alias) // 8):
                    continue
                score = fuzz.ratio(alias, phrase)
                if score > best_score:
                    best_score, best_keys = score, set(aliases[alias])
                elif score == best_score:
                    best_keys.update(aliases[alias])
            if best_score >= threshold and len(best_keys) == 1:
                found.setdefault(next(iter(best_keys)), phrase)
                occupied.update(span)

    return found


class ScanService:
    def __init__(self):
        self._reader = None
        self._reader_lock = threading.Lock()

    @property
    def reader(self):
        # EasyOCR pulls in torch and downloads its models on first construction,
        # so defer it until the first scan instead of paying for it on import.
        # The lock keeps concurrent first requests from building two readers.
        if self._reader is None:
            with self._reader_lock:
                if self._reader is None:
                    import easyocr
                    self._reader = easyocr.Reader(['en'], gpu=False)
        return self._reader

    def extract_text(self, image_bytes):
        return self.reader.readtext(image_bytes, detail=0)

    def calculate_risk_score(self, additive):
        factors = (additive.toxicity_level, additive.exposure_level,
                   additive.sensitivity_level, additive.cumulative_level)
        if any(value is None for value in factors):
            return None
        return round(sum(value * weight / 10 for value, weight in zip(factors, (0.4, 0.3, 0.2, 0.1))), 2)

    def determine_traffic_light(self, risk_score):
        if risk_score is None:
            return "Unrated"
        if risk_score > 0.7:
            return "Red"
        if risk_score >= 0.4:
            return "Yellow"
        return "Green"

    @classmethod
    def refresh_alias_index(cls):
        current_app.extensions.pop("additive_alias_index", None)

    @staticmethod
    def _build_index(additives):
        aliases = defaultdict(set)
        codes = {}
        for key, additive in additives.items():
            if additive.e_number:
                codes[normalize_e_number(additive.e_number)] = key
            for value in [additive.name, *(additive.aliases or [])]:
                phrase = normalize_phrase(value)
                if not phrase or not re.search(r"[^\W\d_]", phrase) or normalize_e_number(value):
                    continue
                aliases[phrase].add(key)
        fuzzy = defaultdict(list)
        widths = set()
        for phrase in aliases:
            width = len(phrase.split())
            widths.add(width)
            if len(phrase.replace(" ", "")) >= 6:
                fuzzy[(width, phrase[0])].append(phrase)
        return aliases, codes, fuzzy, sorted(widths, reverse=True)

    def analyze_image(self, image_bytes, additives_cache=None):
        extracted_text = self.extract_text(image_bytes)
        if additives_cache is not None:
            additives = dict(enumerate(additives_cache))
            index = self._build_index(additives)
        else:
            key = tuple(db.session.execute(select(func.count(Additive.id), func.max(Additive.id))).one())
            cached = current_app.extensions.get("additive_alias_index")
            if cached is None or cached[0] != key:
                additives = {a.id: a for a in Additive.query.all()}
                index = self._build_index(additives)
                current_app.extensions["additive_alias_index"] = (key, index)
            else:
                index = cached[1]

        found = match_additives(extracted_text, index)

        if additives_cache is None:
            additives = {a.id: a for a in Additive.query.filter(Additive.id.in_(found)).all()} if found else {}
        results = []
        for key in sorted(found):
            additive = additives[key]
            risk_score = self.calculate_risk_score(additive)
            results.append({
                "name": additive.name,
                "matched_text": found[key],
                "risk_score": risk_score,
                "traffic_light": self.determine_traffic_light(risk_score),
                "details": additive.to_dict(),
            })
        return results
