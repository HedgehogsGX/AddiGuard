I understand the stack and scope for "AddiGuard" perfectly.

**Tech Stack Confirmed:**
- **Frontend:** React Native (Expo) + TypeScript + Tamagui (Modern UI) + expo-camera.
- **Backend:** Python Flask + Docker.
- **Database:** SQLite (Local) / PostgreSQL (Prod).
- **OCR/AI:** EasyOCR + Custom Risk Algorithm.

Here is the implementation plan for the MVP:

# AddiGuard MVP Implementation Plan

## Phase 1: Project Initialization & Structure
1.  **Directory Setup**: Create a monorepo-style structure (`/backend`, `/frontend`).
2.  **Backend Init**: Setup Python virtual environment, install `flask`, `easyocr`, `sqlalchemy`.
3.  **Frontend Init**: Initialize Expo project with TypeScript.

## Phase 2: Backend Development (Core Logic)
1.  **Database Models**: Define schemas for `Ingredients` and `RiskAnalysis`.
2.  **Risk Engine**: Implement the `total_risk` formula:
    -   `total_risk = (toxicity_score * 0.4) + (exposure_risk * 0.3) + (sensitivity * 0.2) + (cumulative_effect * 0.1)`
3.  **OCR Service**: Integrate EasyOCR to process uploaded images and extract text.
4.  **API Endpoints**:
    -   `POST /analyze`: Accepts image/text, runs OCR, calculates risk, returns traffic light status.

## Phase 3: Frontend Development (Mobile App)
1.  **UI Setup**: Configure Tamagui for the "Medical/Health" aesthetic (Green/Red/Yellow theme).
2.  **Camera Module**: Implement real-time camera view with a frame overlay for scanning.
3.  **Image Handling**: Capture image and send to Backend API.
4.  **Result Display**: Build the "Traffic Light" result screen with detailed alerts.

## Phase 4: Integration & MVP Verification
1.  **End-to-End Test**: Scan a sample label -> OCR extraction -> Risk Score -> UI Display.
2.  **Dockerization**: Create `Dockerfile` for the backend.

I am ready to start. Please approve the plan, and let me know if you want to begin with the **Backend** or **Frontend**.