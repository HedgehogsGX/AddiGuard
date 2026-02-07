I will implement the Backend API with the requested structure and features.

**Implementation Plan:**

1.  **Dependencies**: Update `requirements.txt` to include `thefuzz` (for fuzzy matching), `python-Levenshtein`, and `Pillow`.
2.  **Structure Refinement**:
    -   Restructure `backend/` to follow the `app/` factory pattern.
    -   `backend/app/models.py`: Define `Additive` model with `toxicity_level`, `exposure_level`, `sensitivity_level`, `cumulative_level` (to support the risk formula).
    -   `backend/app/services/scan_service.py`: Implement `OCRService` and `RiskEngine`.
    -   `backend/app/routes.py`: Define the `/api/scan` endpoint.
    -   `backend/app/__init__.py`: Initialize Flask, DB, and register routes.
    -   `backend/run.py`: Entry point.
3.  **Database Seeding**:
    -   Create `backend/seed.py` to populate the 5 dummy additives with the required risk scores.
4.  **Risk Logic**:
    -   Implement the formula: `(toxicity * 0.4) + (exposure * 0.3) + (sensitivity * 0.2) + (cumulative * 0.1)`.
    -   Normalize inputs (1-10 scale) to 0-1 if needed, or keep as raw score. I'll assume the formula produces a 0-10 or 0-1 score. The user said: "If > 0.7 -> High Risk". This implies the result is 0.0 to 1.0. So I will normalize the 1-10 inputs to 0.1-1.0 before calculation.

**Files to be created/modified:**
-   `backend/requirements.txt`
-   `backend/app/__init__.py`
-   `backend/app/models.py`
-   `backend/app/services/scan_service.py`
-   `backend/app/routes.py`
-   `backend/run.py`
-   `backend/seed.py`

I will now execute this plan.