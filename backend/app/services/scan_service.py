import easyocr
import numpy as np
from thefuzz import process
from app.models import Additive

class ScanService:
    def __init__(self):
        # Initialize EasyOCR reader (load once)
        # For production, consider moving this to app startup or lazy loading
        self.reader = easyocr.Reader(['en'], gpu=False)

    def extract_text(self, image_bytes):
        """
        Extract text from image bytes using EasyOCR.
        """
        try:
            result = self.reader.readtext(image_bytes, detail=0)
            return result
        except Exception as e:
            print(f"OCR Error: {e}")
            return []

    def calculate_risk_score(self, additive):
        """
        Risk Formula:
        total_risk = (toxicity_score * 0.4) + (exposure_risk * 0.3) + (sensitivity * 0.2) + (cumulative_effect * 0.1)
        
        Input levels are 1-10. We normalize to 0.1-1.0 for the formula if needed, 
        OR we calculate on 1-10 scale and divide by 10 to get 0-1 range.
        
        Let's calculate on 1-10 scale first.
        """
        # Normalize 1-10 to 0.1-1.0
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
            
        additive_names = [a.name for a in all_additives]
        
        found_additives = []
        
        # Simple text matching (can be improved)
        # We iterate over extracted words and try to find fuzzy match in DB
        # Alternatively, iterate over DB additives and check if they exist in text
        
        # Strategy: Iterate through DB names and check if they appear in the extracted text (fuzzy)
        # Combine extracted text into one string for easier searching? 
        # Or match line by line.
        
        full_text = " ".join(extracted_text).lower()
        
        for additive in all_additives:
            # Fuzzy match score
            # partial_ratio matches substring
            match_score = process.extractOne(additive.name.lower(), [full_text], scorer=process.fuzz.partial_ratio)
            
            if match_score and match_score[1] > 85: # Threshold for match
                risk_score = self.calculate_risk_score(additive)
                traffic_light = self.determine_traffic_light(risk_score)
                
                found_additives.append({
                    "name": additive.name,
                    "risk_score": risk_score,
                    "traffic_light": traffic_light,
                    "details": additive.to_dict()
                })
                
        return found_additives
