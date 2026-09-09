# AddiGuard

Point your phone at an ingredients label and AddiGuard tells you which food additives it found and how risky they are.

The Expo app crops a photo to the on-screen ingredients frame and posts it to a Flask API. The API runs OCR on the image (EasyOCR), matches E-numbers, names and aliases against a database of additives, and returns a Red / Yellow / Green rating for curated additives or Unrated when risk information is missing, plus an overall rating for the label.

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
python import_additives.py          # upserts the bundled Open Food Facts taxonomy, offline
FLASK_DEBUG=1 python run.py         # serves on http://0.0.0.0:5000
```

The OCR models (~100 MB) are downloaded on the first `/api/scan` request, so expect that call to be slow once.

The additive schema includes a unique, nullable `e_number` (for example `E250`, `E150a` or `E101(i)`) and a JSON list of lowercase aliases. `seed.py` destructively rebuilds the database, so run it to adopt the new schema on an existing development database; there is no migration system yet. Back up any data you need first. The importer can then be run repeatedly without duplicating additives. It preserves the five seeded additives' existing factors and does not assign risk factors to newly imported entries. The bundled snapshot imports 643 concrete E-number entries, of which 638 are Unrated after seeding. Generic taxonomy categories and wildcard codes are excluded.

The unmodified Open Food Facts snapshot and its source, checksum and licensing information are in `backend/data/`; importing and testing do not require network access. To use an updated raw taxonomy, run `python import_additives.py /path/to/additives.txt`. The importer invalidates the current process's alias index; restart other running API processes after import, particularly when updating existing aliases without adding rows.

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
npm test                          # pure crop geometry tests, no device required
npx tsc --noEmit
npx expo start
```

The app needs to reach the backend. By default it targets port 5000 on the machine that serves the Expo dev bundle, which works for a physical device on the same Wi‑Fi and for emulators. To point it elsewhere, create `frontend/.env`:

```
EXPO_PUBLIC_API_URL=http://192.168.1.20:5000/api
```

In development builds a **Mock Mode** switch on the camera screen returns canned results so the UI can be exercised without a backend.

The camera measures the preview and scan frame, maps the frame through the preview's centered aspect-ratio fill to captured photo pixels, and crops before upload. The cropped image is downscaled to at most 1600 pixels on its long side and encoded as JPEG at quality 0.8. Only the framed region is sent to OCR. Mock Mode bypasses image processing. Scan results live in a React context rather than URL parameters; opening the results route without an in-memory scan redirects to the camera.

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
      "matched_text": "e250",
      "risk_score": 0.83,
      "traffic_light": "Red",
      "details": { "id": 1, "name": "Sodium Nitrite", "e_number": "E250", "aliases": ["sodium nitrite"], "toxicity_level": 9, "...": "..." }
    }
  ]
}
```

Errors return `{ "error": "..." }` with a 4xx/5xx status.

Each result includes `matched_text`, the normalized OCR phrase or code that triggered detection. Names and aliases match on phrase boundaries, with conservative fuzzy matching for longer aliases to tolerate OCR mistakes; short aliases such as `MSG` only match exactly. Explicit E-number variants such as `E 250` and `E-250` are recognized, while bare numbers require an additive-class context such as `preservative (250)` or `flavour enhancer (621)`. Multiple hits for the same additive produce one result.

### Risk score

Each additive has four 1–10 factors. The score is a weighted sum normalised to 0–1:

```
risk = toxicity·0.4 + exposure·0.3 + sensitivity·0.2 + cumulative·0.1
```

`> 0.7` is Red, `0.4–0.7` is Yellow, `< 0.4` is Green. The overall label rating is the highest-scoring additive found. The backend is the only place these thresholds live; the app just renders the `traffic_light` values it receives.

If any risk factor is null, that additive has `risk_score: null` and `traffic_light: "Unrated"`. Unrated detections are shown with a grey information badge and excluded from the overall score; they are not a claim of safety. If every detection is Unrated, the overall score is null and the overall traffic light is Unrated. An empty result retains `overall_risk_score: 0` and `overall_traffic_light: "Green"` for compatibility; no detection is not proof of a safe label.

## Status

Early MVP. The seed data has five additives with placeholder risk factors and health notes; none of it is medical advice. Open Food Facts expands detection coverage, not the curated risk database. OCR and approximate matching can still miss ingredients or return false positives, and the preview-to-photo mapping still needs validation on physical iOS and Android devices.
