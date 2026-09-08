# AddiGuard

AddiGuard photographs an ingredient label and sends the image to a configured,
OpenAI-compatible vision model. The server validates the model's JSON response and
returns only provider-sourced ingredient facts; it has no bundled additive catalog,
OCR engine, local risk formula, or persisted scan results.

## Project Structure

- **backend/**: Python Flask application
- **frontend/**: React Native (Expo) application

## Getting started

### Backend

Python 3.11+ is recommended. From the repository root:

```sh
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r backend/requirements.txt
cp backend/.env.example backend/.env
```

Set `OPENAI_API_KEY` in the environment (or load `backend/.env` with your preferred
dotenv tool), then start the actual app:

```sh
cd backend
python3 run.py
```

`OPENAI_BASE_URL` defaults to `https://api.openai.com/v1`; it can point to any
OpenAI-compatible `/chat/completions` server. `OPENAI_MODEL` defaults to
`gpt-4o-mini`, which must support image input. `OPENAI_TIMEOUT_SECONDS` controls the
provider request timeout. The key is used only server-side and is never sent to the
frontend or logged.

### iOS frontend

Install the Expo dependencies and configure the API URL. The app is an Expo/React
Native iOS app; web export is only a convenient verification target:

```sh
cd frontend
npm install
cp .env.example .env
npm start         # open in Expo Go or an iOS development build
```

Set `EXPO_PUBLIC_API_URL` to the reachable Flask URL, including `/api`. An iPhone
cannot resolve the computer's `localhost`, so use the computer's LAN IP (for
example `http://192.168.1.20:5000/api`) and ensure the Flask port is reachable on
the same network. `npm run web` remains available for browser verification.

## API contract and privacy

`POST /api/scan` accepts one multipart field named `image`. JPEG, PNG, and WebP
images up to 8 MB are accepted. A successful response is:

```json
{
  "status": "success",
  "additives_found": 1,
  "results": [{
    "name": "ingredient name as read",
    "risk_score": null,
    "traffic_light": null,
    "details": {
      "name": "ingredient name as read",
      "description": null,
      "health_risk": null,
      "usage_limit": null,
      "toxicity_level": null,
      "exposure_level": null,
      "sensitivity_level": null,
      "cumulative_level": null
    }
  }]
}
```

The complete system prompt is versioned at
`backend/app/prompts/analyze_additives.txt`. It covers multilingual recognition
(including Chinese ingredient names), prompt-injection resistance, explicit
readability detection, nullable unknown details, and strict limits against invented
scores or dosages. An unreadable label is a `422` error; provider failures are
sanitized `502`/`504` responses and missing server configuration is `503`.

Images are sent to the configured remote vision provider for analysis. Images and
results are not persisted locally, and no local additive database is used. On app
startup the narrowly scoped migration drops only the old `additives` table from
`backend/instance/addiguard.db` if that file exists. To clean an alternate legacy
installation, set `LEGACY_DB_PATH` to its explicit absolute path; all unrelated
tables are preserved. `backend/seed.py` is now cleanup-only and never seeds data.

## Tests

Run backend regression tests with:

```sh
python3 -m unittest discover -s backend/tests -v
```

Frontend type checking and the web bundle can be run with:

```sh
cd frontend
npm run typecheck
npm run build:web
```
