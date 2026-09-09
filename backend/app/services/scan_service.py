import threading

from thefuzz import fuzz, utils

from app.models import Additive


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
        """
        Extract text from image bytes using EasyOCR.
        """
        return self.reader.readtext(image_bytes, detail=0)

    def calculate_risk_score(self, additive):
        """
        Risk Formula:
        total_risk = (toxicity_score * 0.4) + (exposure_risk * 0.3) + (sensitivity * 0.2) + (cumulative_effect * 0.1)

        Input levels are 1-10, normalized to 0.1-1.0 so the result lands in the 0-1 range.
        """
        t = additive.toxicity_level / 10.0
        e = additive.exposure_level / 10.0
        s = additive.sensitivity_level / 10.0
        c = additive.cumulative_level / 10.0

        total_risk = (t * 0.4) + (e * 0.3) + (s * 0.2) + (c * 0.1)
        return round(total_risk, 2)

    def determine_traffic_light(self, risk_score):
        """
        If > 0.7 -> High Risk (Red)
        0.4-0.7 -> Medium (Yellow)
        < 0.4 -> Low (Green)
        """
        if risk_score > 0.7:
            return "Red"
        elif risk_score >= 0.4:
            return "Yellow"
        else:
            return "Green"

    def analyze_image(self, image_bytes, additives_cache=None):
        """
        1. Extract text
        2. Match against DB
        3. Calculate Risk
        """
        extracted_text = self.extract_text(image_bytes)

        # Get all additives from DB (optimize by caching or specific query later)
        # For MVP, fetching all names is fine if list is small.
        if additives_cache is None:
            all_additives = Additive.query.all()
        else:
            all_additives = additives_cache

        found_additives = []

        # Strategy: Iterate through DB names and check if they appear in the extracted text (fuzzy).
        # full_process lowercases and turns punctuation into spaces so "vitamin-c" still matches "Vitamin C".
        full_text = utils.full_process(" ".join(extracted_text))

        for additive in all_additives:
            # partial_ratio matches substring
            match_score = fuzz.partial_ratio(utils.full_process(additive.name), full_text)

            if match_score > 85: # Threshold for match
                risk_score = self.calculate_risk_score(additive)
                traffic_light = self.determine_traffic_light(risk_score)

                found_additives.append({
                    "name": additive.name,
                    "risk_score": risk_score,
                    "traffic_light": traffic_light,
                    "details": additive.to_dict()
                })

        return found_additives
