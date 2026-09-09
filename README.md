# AddiGuard

Point your phone at an ingredients label and AddiGuard tells you which food additives it found and how risky they are.

The Expo app takes a photo and posts it to a Flask API. The API runs OCR on the image (EasyOCR), fuzzy-matches the text against a database of additives, scores each hit, and returns a Red / Yellow / Green traffic light per additive plus an overall rating for the label.

## Project structure

- **backend/** – Flask API (`POST /api/scan`), SQLite via Flask-SQLAlchemy, EasyOCR + thefuzz for matching.
- **frontend/** – Expo (React Native) app with a camera screen and a results screen.

## Backend

Requires Python 3.12.

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt     # CPU-only torch; ~1 GB
python seed.py                      # (re)creates the SQLite DB with sample additives
FLASK_DEBUG=1 python run.py         # serves on http://0.0.0.0:5000
```

The OCR models (~100 MB) are downloaded on the first `/api/scan` request, so expect that call to be slow once.

Configuration is via environment variables:

| Variable       | Default                  | Purpose                                  |
| -------------- | ------------------------ | ---------------------------------------- |
| `DATABASE_URL` | `sqlite:///addiguard.db` | SQLAlchemy connection string             |
| `FLASK_DEBUG`  | unset                    | Set to `1` for the debugger and reloader |
| `PORT`         | `5000`                   | Port for `python run.py`                 |

Uploads are capped at 10 MB and must decode as an image.

### Tests

```bash
pip install -r requirements-dev.txt
pytest
```

## Frontend

```bash
cd frontend
npm ci
npx expo start
```

The app needs to reach the backend. By default it targets port 5000 on the machine that serves the Expo dev bundle, which works for a physical device on the same Wi‑Fi and for emulators. To point it elsewhere, create `frontend/.env`:

```
EXPO_PUBLIC_API_URL=http://192.168.1.20:5000/api
```

In development builds a **Mock Mode** switch on the camera screen returns canned results so the UI can be exercised without a backend.

## API

`POST /api/scan` with a `multipart/form-data` body containing an `image` file.

```json
{
  "status": "success",
  "additives_found": 1,
  "overall_risk_score": 0.83,
  "overall_traffic_light": "Red",
  "results": [
    {
      "name": "Sodium Nitrite",
      "risk_score": 0.83,
      "traffic_light": "Red",
      "details": { "id": 1, "name": "Sodium Nitrite", "toxicity_level": 9, "...": "..." }
    }
  ]
}
```

Errors return `{ "error": "..." }` with a 4xx/5xx status.

### Risk score

Each additive has four 1–10 factors. The score is a weighted sum normalised to 0–1:

```
risk = toxicity·0.4 + exposure·0.3 + sensitivity·0.2 + cumulative·0.1
```

`> 0.7` is Red, `0.4–0.7` is Yellow, `< 0.4` is Green. The overall label rating is the highest-scoring additive found. The backend is the only place these thresholds live; the app just renders the `traffic_light` values it receives.

## Status

Early MVP. The seed data has five additives with placeholder risk factors and health notes; none of it is medical advice. Matching is by additive name only (no E-numbers or synonyms yet), so real labels will be missed until the additive dataset is expanded.
