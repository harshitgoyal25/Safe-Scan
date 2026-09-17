# SafeScan

> **A machine-learning-powered Android cybersecurity application that screens APK files, SMS messages, and URLs for malicious content before you trust them.**

SafeScan is an end-to-end mobile security platform built with a **Flutter** Android frontend and a **Python FastAPI** backend, secured by **Firebase Authentication** and backed by **Cloud Firestore**. Three independent machine-learning detectors operate in tandem to analyze files, messages, and web links, supported by real-time background listeners and automated APK screening.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Repository Structure](#repository-structure)
4. [Backend — Python FastAPI](#backend--python-fastapi)
   - [app/main.py](#appmainpy)
   - [app/extractor.py](#appextractorpy)
   - [app/sms_detector.py](#appsms_detectorpy)
   - [app/url_detector.py](#appurl_detectorpy)
   - [app/url_extractor.py](#appurl_extractorpy)
   - [test_api.py (Automated Tests)](#test_apipy)
5. [ML Models](#ml-models)
   - [APK Malware Detector](#apk-malware-detector)
   - [SMS Spam / Malicious Detector](#sms-spam--malicious-detector)
   - [URL Phishing Detector](#url-phishing-detector)
6. [Model Artifacts](#model-artifacts)
7. [API Reference](#api-reference)
   - [GET /](#get-)
   - [GET /health](#get-health)
   - [POST /scan (APK)](#post-scan--apk-analysis)
   - [POST /scan/sms (SMS)](#post-scansms--sms-analysis)
   - [POST /scan/url (URL)](#post-scanurl--url-analysis)
   - [POST /scan/history (History Sync)](#post-scanhistory--scan-history-logging)
8. [Frontend — Flutter Android](#frontend--flutter-android)
   - [Design System & Cyber Theme](#design-system--cyber-theme)
   - [UI Widgets & Threat Gauges](#ui-widgets--threat-gauges)
   - [lib/main.dart & Auth Routing](#libmaindart)
   - [lib/screens/splash_screen.dart](#libscreenssplash_screendart)
   - [lib/screens/login_screen.dart](#libscreenslogin_screendart)
   - [lib/screens/home_screen.dart](#libscreenshome_screendart)
   - [lib/screens/history_screen.dart](#libscreenshistory_screendart)
   - [lib/screens/scan_screen.dart & result_screen.dart](#libscreensscan_screendart--result_screendart)
   - [lib/screens/sms_scan_screen.dart & sms_result_screen.dart](#libscreenssms_scan_screendart--sms_result_screendart)
   - [lib/screens/url_scan_screen.dart & url_result_screen.dart](#libscreensurl_scan_screendart--url_result_screendart)
   - [lib/services/api_service.dart](#libservicesapi_servicedart)
   - [lib/services/scan_history_service.dart](#libservicesscan_history_servicedart)
   - [lib/services/apk_auto_scan_service.dart & Native Android Integration](#libservicesapk_auto_scan_servicedart--native-android-integration)
   - [lib/services/sms_background_service.dart](#libservicessms_background_servicedart)
   - [lib/services/notification_service.dart](#libservicesnotification_servicedart)
   - [lib/services/startup_service.dart](#libservicesstartup_servicedart)
9. [Performance Metrics](#performance-metrics)
10. [Setup & Running](#setup--running)
    - [Backend Setup & Testing](#backend-setup)
    - [Frontend Setup & Testing](#frontend-setup)
11. [Dependencies](#dependencies)
12. [Important Limitations & Security Notes](#important-limitations--security-notes)

---

## Project Overview

SafeScan delivers three distinct cybersecurity detection capabilities via a unified, polished mobile interface:

| Scanner | Input | What it detects | Operating Mode |
|---|---|---|---|
| **APK Scanner** | `.apk` binary file | Android malware via static analysis (permissions, intents, DEX API calls) | On-demand file upload + Automated background package detection |
| **SMS Scanner** | SMS message text | Phishing, fraudulent messages, banking scams, and spam | On-demand paste/scan + Real-time background incoming SMS monitor |
| **URL Scanner** | Web link / domain | Phishing sites, credential harvesting, malicious web endpoints | On-demand text input & validation |

### End-to-End Workflow:
1. **User Authentication:** Users sign in using Firebase Authentication (Email/Password, Google Sign-In, or Guest mode).
2. **Threat Screening:** The user uploads a file or inputs text (or incoming SMS/APKs are intercepted by background services).
3. **High-Availability API Processing:** The Flutter client sends scan requests to the FastAPI backend and syncs scan history with Firebase Bearer token (`Authorization: Bearer <ID_token>`).
4. **Machine Learning Inference:** The backend applies pre-trained LightGBM and Logistic Regression models using exact decision thresholds.
5. **Dynamic Visual Feedback:** The app visualizes the threat probability using custom circular and linear risk gauges with actionable security recommendations.
6. **Persistent History:** Every completed scan is automatically saved to Cloud Firestore and accessible through the scan history viewer.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Flutter Android Client                           │
│  (Cyber Dark Theme · Animated Gauges · Splash Screen · Auth Gate)       │
│                                                                         │
│  [StartupService] ──► [Firebase Auth / Firestore] ──► [AuthGate]        │
│                                                            │            │
│  ┌─────────────────────── HomeScreen ───────────────────┼──────────┐   │
│  │                                                      ▼          │   │
│  │  • Active Protection Toggles:                   LoginScreen     │   │
│  │    ├─ SMS Auto-Protection (SmsBackgroundService)                │   │
│  │    └─ APK Auto-Detection (ApkAutoScanService)                   │   │
│  │                                                                 │   │
│  │  • Scanners & Results:                          HistoryScreen   │   │
│  │    ├─ ScanScreen   (APK)  ──► ResultScreen         (Firestore   │   │
│  │    ├─ SmsScanScreen (SMS) ──► SmsResultScreen       sync and    │   │
│  │    └─ UrlScanScreen (URL) ──► UrlResultScreen       filtering)  │   │
│  └───────────────────────────┬─────────────────────────────────────┘   │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
               Bearer Token    │ HTTP / Multipart
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          FastAPI Backend                                │
│                                                                         │
│  • Firebase Admin SDK (auth.verify_id_token, firestore.client)          │
│                                                                         │
│  POST /scan            ──► extractor.py (LightGBM)                       │
│  POST /scan/sms        ──► sms_detector (LogReg)                        │
│  POST /scan/url        ──► url_detector (LogReg)                        │
│  POST /scan/history    ──► current_user_id ──► Firestore Users Doc     │
│  GET  /health          ──► System Health Check                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
SafeScan/
├── .gitignore                  # Git ignore rules (builds, local secrets, scratch files)
├── README.md                   # Complete architectural, ML, and developer documentation
│
├── safescan_backend/           # Python FastAPI backend service
│   ├── app/
│   │   ├── main.py             # FastAPI app, Firebase Admin auth, all HTTP endpoints
│   │   ├── extractor.py        # APK static analysis + LightGBM inference
│   │   ├── sms_detector.py     # SMS TF-IDF + Logistic Regression inference
│   │   ├── url_detector.py     # URL TF-IDF + Logistic Regression inference
│   │   └── url_extractor.py    # Legacy lexical extractor (reference only)
│   ├── models/
│   │   ├── apk_model/
│   │   │   ├── model.pkl           # Trained LightGBM classifier
│   │   │   ├── feature_names.csv   # All 24,833 original feature names
│   │   │   ├── selected_features.csv # 10,000 chi-square-selected features
│   │   │   └── config.json         # Model hyperparameters + threshold (0.52)
│   │   ├── sms_model/
│   │   │   ├── sms_model.pkl       # Trained Logistic Regression classifier
│   │   │   ├── sms_word_vectorizer.pkl # Word-level TF-IDF vectorizer
│   │   │   └── sms_char_vectorizer.pkl # Character-level TF-IDF vectorizer
│   │   └── url_model/
│   │       ├── url_model.pkl       # Trained Logistic Regression classifier
│   │       ├── url_word_vectorizer.pkl # Word-level TF-IDF vectorizer
│   │       ├── url_char_vectorizer.pkl # Character-level TF-IDF vectorizer
│   │       └── config.json         # Model hyperparameters + threshold (0.41)
│   ├── test_api.py             # Pytest automated test suite for endpoints & auth
│   ├── test_extractor.py       # Standalone verification script for APK extractor
│   ├── test_sms_detector.py    # Standalone verification script for SMS detector
│   ├── test_url_detector.py    # Standalone verification script for URL detector
│   └── requirements.txt        # Python backend dependencies
│
└── safescan_frontend/          # Flutter Android application
    ├── android/                # Native Android configuration
    │   ├── app/src/main/
    │   │   ├── AndroidManifest.xml # Permissions (SMS, notifications, foreground service)
    │   │   ├── kotlin/.../
    │   │   │   ├── MainActivity.kt   # MethodChannel bridge for native services
    │   │   │   └── ApkScanService.kt # Foreground service & broadcast receiver for APKs
    │   │   └── res/            # Launcher icons, splash bitmaps, and styles
    ├── assets/
    │   └── images/
    │       └── safescan_logo.png     # SafeScan brand shield logo
    ├── lib/
    │   ├── main.dart                 # App initialization, AuthGate, theme declaration
    │   ├── firebase_options.dart     # Generated Firebase platform configurations
    │   ├── models/
    │   │   └── scan_result.dart      # APK scan result data model
    │   ├── screens/
    │   │   ├── splash_screen.dart    # Animated startup screen with pulse animation
    │   │   ├── login_screen.dart     # Authentication (Email, Google, Guest mode)
    │   │   ├── home_screen.dart      # Central dashboard, protection toggles, scan cards
    │   │   ├── history_screen.dart   # Filterable scan history with Firestore sync
    │   │   ├── scan_screen.dart      # APK file picker + upload trigger
    │   │   ├── result_screen.dart    # APK scan results + ThreatCircleGauge
    │   │   ├── sms_scan_screen.dart  # SMS input form
    │   │   ├── sms_result_screen.dart# SMS scan results + threat classification
    │   │   ├── url_scan_screen.dart  # URL input form
    │   │   └── url_result_screen.dart# URL scan results + domain breakdown
    │   ├── services/
    │   │   ├── api_service.dart      # HTTP client for all FastAPI endpoints with auth
    │   │   ├── apk_auto_scan_service.dart # Background APK auto-scan controller
    │   │   ├── notification_service.dart  # Local Android push notification manager
    │   │   ├── scan_history_service.dart  # Firestore scan logging & query service
    │   │   ├── sms_background_service.dart# Telephony incoming SMS receiver
    │   │   └── startup_service.dart  # Multi-phase app startup orchestrator
    │   ├── theme/
    │   │   └── app_theme.dart        # Cyber dark theme, color tokens, typography
    │   └── widgets/
    │       ├── custom_widgets.dart   # CyberCard, GlowingButton, StatusBadge, etc.
    │       └── threat_gauge.dart     # Animated circular and linear threat gauges
    ├── test/
    │   ├── scan_result_test.dart     # Unit tests for ScanResult parsing and getters
    │   ├── splash_screen_test.dart   # Widget tests for SplashScreen UI components
    │   └── widget_test.dart          # Smoke test suite
    └── pubspec.yaml                  # Flutter dependencies and assets
```

---

## Backend — Python FastAPI

### `app/main.py`

**The central API service.** Initialises `FastAPI(title="SafeScan API", version="1.0.0")`, integrates **Firebase Admin SDK** for Bearer token verification, and exposes high-availability scanning and protected history logging endpoints.

**Global Security & Validation Constraints:**
- `MAX_FILE_SIZE = 200 MB` — maximum APK file upload size.
- `MAX_TEXT_LENGTH = 10,000 characters` — maximum SMS message and URL length.
- `current_user_id` FastAPI dependency: extracts and verifies `Authorization: Bearer <Firebase_ID_token>` for scan history logging (`POST /scan/history`). Unauthenticated requests to `/scan/history` return `HTTP 401 Unauthorized`.
- Primary scan endpoints (`/scan`, `/scan/sms`, `/scan/url`) operate as open high-availability scan services to prevent deployment/credential failures.

**API Endpoints Summary:**

| Method | Endpoint | Auth | Request Body | Description |
|---|---|---|---|---|
| `GET` | `/` | None | None | Service identification and status |
| `GET` | `/health` | None | None | Health check endpoint returning `{"status": "healthy"}` |
| `POST` | `/scan` | None | Multipart `.apk` file | Extracts features with AndroGuard and infers with LightGBM |
| `POST` | `/scan/sms` | None | `{"message": "..."}` | Evaluates message text via dual TF-IDF and Logistic Regression |
| `POST` | `/scan/url` | None | `{"url": "..."}` | Evaluates web link via URL-aware TF-IDF and Logistic Regression |
| `POST` | `/scan/history` | Required | `ScanHistoryRequest` | Logs scan results directly into Firestore under user collection |

---

### `app/extractor.py`

**APK static analysis and LightGBM prediction engine.**

- **Static decompilation:** Uses AndroGuard (`androguard==3.3.5`) to parse the manifest, intent filters, and DEX bytecode without executing the APK.
- **Vocabulary mapping:** Normalizes extracted permissions, intents, and API calls against the 24,833-feature MH-100K training vocabulary.
- **Dimensionality reduction:** Slices the full feature vector down to the 10,000 chi-square selected indices.
- **Classification:** Evaluates feature vector with `LightGBM` using threshold `0.52`.

---

### `app/sms_detector.py`

**SMS classification using dual TF-IDF + Logistic Regression.**

- **Word-level TF-IDF:** Extracts 1–2 n-grams capturing phrases and keywords.
- **Character-level TF-IDF:** Extracts 3–5 n-grams capturing evasive typos, obfuscated letters, and punctuation tricks.
- **Classification:** Stacks both sparse vectors and runs through Logistic Regression (`C=2.0`, threshold `0.40`).

---

### `app/url_detector.py`

**URL classification using dual TF-IDF + Logistic Regression.**

- **URL-aware tokenization:** Uses `token_pattern=[^/\s]+` so path segments, queries, and domains are tokenized without destructive splitting.
- **Dual TF-IDF representation:** Up to 100,000 word features and 100,000 character features (total up to 200,000 sparse inputs).
- **Classification:** Logistic Regression evaluated at threshold `0.41`.

---

### `app/url_extractor.py`

*(Legacy reference module)* Implements a 78-feature lexical/structural extractor based on the ISCX-URL2016 definition. Preserved for academic reference and comparison; active inference uses the higher-accuracy TF-IDF model in `app/url_detector.py`.

---

### `test_api.py`

Pytest test suite validating API robustness:
- Verification of scan endpoints without auth requirements.
- History logging endpoint authorization checks (`HTTP 401` on missing/invalid token).
- Rejection of empty SMS text and empty APK uploads (`HTTP 400`).

---

## ML Models

### APK Malware Detector

| Property | Value |
|---|---|
| **Dataset** | MH-100K Android Malware Dataset |
| **Dataset size** | 101,934 samples (data period: 2010–2022; labels derived from VirusTotal) |
| **Original features** | 24,833 total — 166 permissions, 250 intents, 24,417 API calls |
| **Feature reduction step 1** | Frequency filter (min frequency 2 in training set) → 21,169 features |
| **Feature reduction step 2** | Chi-square feature selection → **10,000 features** |
| **Algorithm** | LightGBM binary classifier |
| **Hyperparameters** | 500 estimators, learning rate 0.05, 31 leaves, `class_weight=balanced`, `subsample=0.8`, `colsample_bytree=0.8`, `reg_alpha=0.1`, `reg_lambda=0.1` |
| **Static analysis tool** | AndroGuard 3.3.5 |
| **Production threshold** | **0.52** (maximises precision while keeping recall >= 95%) |
| **Data split** | Stratified 70% train / 15% validation / 15% test, `random_state=42` |

---

### SMS Spam / Malicious Detector

| Property | Value |
|---|---|
| **Dataset** | UCI SMS Spam Collection |
| **Dataset size** | 5,158 clean messages (4,516 benign + 642 malicious/spam) |
| **Features** | Word-level TF-IDF (1–2 grams) + Character-level TF-IDF (3–5 grams), combined sparse matrix |
| **Algorithm** | Logistic Regression (`C=2.0`, `class_weight=balanced`) |
| **Production threshold** | **0.40** |
| **Data split** | Stratified 70% train / 15% validation / 15% test, `random_state=42` |

---

### URL Phishing Detector

| Property | Value |
|---|---|
| **Dataset** | `URL dataset.csv` — 450,176 URLs (345,738 legitimate + 104,438 phishing) |
| **Features** | Word TF-IDF (`[^/\s]+` pattern, 1–2 grams, max 100k) + Char TF-IDF (3–5 grams, max 100k) |
| **Algorithm** | Logistic Regression (`C=2.0`, `class_weight=balanced`, `solver=liblinear`, `max_iter=2000`) |
| **Production threshold** | **0.41** |
| **Data split** | Stratified 70% train / 15% validation / 15% test, `random_state=42` |

---

## Model Artifacts

All serialised models and vocabulary tables reside in `safescan_backend/models/`:

| File | Format | Size | Description |
|---|---|---|---|
| `apk_model/model.pkl` | pickle / joblib | ~1.9 MB | Trained LightGBM binary classifier |
| `apk_model/feature_names.csv` | CSV | ~850 KB | All 24,833 MH-100K feature names in training order |
| `apk_model/selected_features.csv` | CSV | ~350 KB | The 10,000 chi-square-selected feature names |
| `apk_model/config.json` | JSON | <1 KB | Hyperparameters, split config, threshold (0.52) |
| `sms_model/sms_model.pkl` | joblib | ~485 KB | Trained Logistic Regression SMS classifier |
| `sms_model/sms_word_vectorizer.pkl` | joblib | ~398 KB | Fitted word-level TF-IDF vectorizer |
| `sms_model/sms_char_vectorizer.pkl` | joblib | ~1.7 MB | Fitted character-level TF-IDF vectorizer |
| `url_model/url_model.pkl` | joblib | ~1.6 MB | Trained Logistic Regression URL classifier |
| `url_model/url_word_vectorizer.pkl` | joblib | ~4.9 MB | Fitted word-level TF-IDF vectorizer |
| `url_model/url_char_vectorizer.pkl` | joblib | ~3.4 MB | Fitted character-level TF-IDF vectorizer |
| `url_model/config.json` | JSON | <1 KB | Hyperparameters, threshold (0.41), test metrics |

---

## API Reference

Base URL (default local): `http://localhost:8000`  
Android Emulator Loopback: `http://10.0.2.2:8000`

### `GET /`
Returns basic service info.
```json
{ "name": "SafeScan API", "status": "running", "version": "1.0.0" }
```

### `GET /health`
Liveness and readiness health check.
```json
{ "status": "healthy" }
```

### `POST /scan` — APK Analysis
- **Headers:** None
- **Body:** `multipart/form-data` with form field `file` containing `.apk`.
- **Response:**
```json
{
  "filename": "suspicious_app.apk",
  "prediction": "Malicious",
  "probability": 0.8924,
  "threshold": 0.52,
  "matched_features": 312,
  "active_features": 87
}
```

### `POST /scan/sms` — SMS Analysis
- **Headers:** None
- **Body:**
```json
{ "message": "Urgent: Your bank account is locked. Verify at https://secure-login-bank.net" }
```
- **Response:**
```json
{
  "prediction": "Malicious",
  "probability": 0.9412,
  "threshold": 0.40
}
```

### `POST /scan/url` — URL Analysis
- **Headers:** None
- **Body:**
```json
{ "url": "https://secure-login-bank.net/account/update" }
```
- **Response:**
```json
{
  "prediction": "Malicious",
  "probability": 0.9821,
  "threshold": 0.41
}
```

### `POST /scan/history` — Scan History Logging
- **Headers:** `Authorization: Bearer <Firebase_ID_token>` (Required)
- **Body:**
```json
{
  "scan_type": "url",
  "input_label": "URL",
  "input_value": "https://secure-login-bank.net",
  "result": {
    "prediction": "Malicious",
    "probability": 0.9821,
    "threshold": 0.41
  }
}
```
- **Status:** `204 No Content` on success.

---

## Frontend — Flutter Android

Built with Flutter 3 (Dart `^3.11.4`), following a cybersecurity-tailored design system.

### Design System & Cyber Theme
Defined in `lib/theme/app_theme.dart`:
- **Palette:** Deep Obsidian `#0A0F1D`, Surface Navy `#111827`, Card Slate `#1F2937`.
- **Accents:** Cyber Teal `#14B8A6`, Emerald Safe `#10B981`, Amber Warning `#F59E0B`, Neon Threat Crimson `#EF4444`.
- **Styling:** Custom glowing outlines, rounded cards, dark backdrop filters, and high-contrast typography.

### UI Widgets & Threat Gauges
- **`ThreatCircleGauge` (`lib/widgets/threat_gauge.dart`):** Animated circular canvas displaying the threat probability with dynamic sweep gradient arcs and centered severity badges.
- **`ThreatLinearGauge` (`lib/widgets/threat_gauge.dart`):** Compact bar gauge for inline list items and cards.
- **`CyberCard` & `GlowingButton` (`lib/widgets/custom_widgets.dart`):** Styled interactive elements with touch elevation and neon borders.

### `lib/main.dart`
Initializes widgets and runs `SafeScanApp`. Uses `AuthGate` to reactively route authenticated users to `HomeScreen` and unauthenticated users to `LoginScreen`, with an initial transition through `SplashScreen`.

### `lib/screens/splash_screen.dart`
A multi-stage animated splash screen featuring:
- Radar scanner animation with breathing logo pulses.
- Step-by-step loading progression driven by `StartupService` (Firebase initialization, notifications, cached auth check).
- Smooth automatic route transition.

### `lib/screens/login_screen.dart`
Full-featured authentication screen:
- Email and password sign-in and account registration.
- Google Sign-In with credential linking.
- Guest / Anonymous mode for instant local testing without sign-up.

### `lib/screens/home_screen.dart`
Comprehensive cybersecurity dashboard:
- **Live Protection Toggles:** One-tap activation for Automatic SMS Protection and Automatic APK Download Scanning.
- **Scanner Cards:** Quick-action cards for APK, SMS, and URL screening.
- **Recent Scan History:** Interactive preview of recent scan activities with direct navigation to the full history screen.
- **User Profile Header:** Active user display with sign-out action.

### `lib/screens/history_screen.dart`
Cloud Firestore-powered scan history viewer:
- Category tabs: **All**, **APK**, **SMS**, **URL**.
- Detailed item cards with threat level badges, timestamp, and target values.
- Tap-to-inspect dialog displaying complete technical attributes and threat likelihood.

### `lib/screens/scan_screen.dart` & `result_screen.dart`
- **Selection:** Native file picker restricted to `.apk` files with size and path validation.
- **Inference Feedback:** Displays full progress animation while uploading and scanning.
- **Result Presentation:** Renders the `ThreatCircleGauge`, detection verdict (Malicious / Benign), risk likelihood tier, matched static feature counts, and actionable guidance.

### `lib/screens/sms_scan_screen.dart` & `sms_result_screen.dart`
Allows pasting or typing SMS text, calls `/scan/sms`, and displays probability analysis, threshold margin, and spam/malicious indicators.

### `lib/screens/url_scan_screen.dart` & `url_result_screen.dart`
Takes any URL, analyzes path, query, and host features, and displays risk score with security recommendations (e.g., avoid entering credentials).

### `lib/services/api_service.dart`
Handles all outgoing HTTP requests to the backend. Injects Firebase ID tokens automatically via `FirebaseAuth.instance.currentUser?.getIdToken()`.

### `lib/services/scan_history_service.dart`
Directly logs scan results into Firestore under `users/{uid}/scan_history` with sanitized JSON payloads and server timestamps.

### `lib/services/apk_auto_scan_service.dart` & Native Android Integration
- **`ApkAutoScanService`:** Flutter service managing permissions and communicating with native Android code via `MethodChannel('safescan/apk_auto_scan')`.
- **`ApkScanService.kt`:** Native Android service that listens for newly downloaded or staged APKs, triggers background static inspection, and emits scan events back to Flutter.

### `lib/services/sms_background_service.dart`
Listens for incoming SMS events in the background using `telephony`. When received, forwards the message payload to the backend and triggers a local notification with the security verdict.

### `lib/services/notification_service.dart`
Configures Android notification channels (`safescan_sms_channel`, `safescan_apk_channel`) and displays high-priority alerts when threats are identified.

### `lib/services/startup_service.dart`
Coordinates ordered service readiness during splash sequence: Firebase platform init, notification channel registration, and local preferences caching.

---

## Performance Metrics

All metrics are evaluated on the **held-out 15% test split** (never seen during training or threshold selection).

| Scanner | Accuracy | Balanced Accuracy | ROC-AUC | PR-AUC |
|---|---|---|---|---|
| **APK Malware** | **96.91%** | **95.74%** | **98.68%** | **90.83%** |
| **SMS Spam / Malicious** | **99.35%** | **98.74%** | **99.86%** | **99.41%** |
| **URL Phishing** | **99.83%** | **99.75%** | **99.98%** | **99.96%** |

### Confusion Matrices (held-out test set)

**APK Malware (15,291 samples):**
| | Predicted Benign | Predicted Malicious |
|---|---|---|
| **Actual Benign** | 13,433 | 388 |
| **Actual Malicious** | 84 | 1,386 |

**SMS (774 samples):**
| | Predicted Benign | Predicted Malicious |
|---|---|---|
| **Actual Benign** | 675 | 3 |
| **Actual Malicious** | 2 | 94 |

**URL (67,527 samples):**
| | Predicted Benign | Predicted Malicious |
|---|---|---|
| **Actual Benign** | 51,806 | 55 |
| **Actual Malicious** | 63 | 15,603 |

---

## Setup & Running

### Backend Setup

**Prerequisites:** Python 3.9+, pip

```bash
# 1. Navigate to backend directory
cd safescan_backend

# 2. Create and activate a virtual environment
python -m venv .venv

# On Windows:
.venv\Scripts\activate
# On macOS/Linux:
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. (Optional) Run backend tests
pytest test_api.py -v

# 5. Start the FastAPI server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Interactive API documentation will be available at `http://localhost:8000/docs`.

> **Note on Firebase Setup:** For the backend to verify Firebase tokens, ensure `GOOGLE_APPLICATION_CREDENTIALS` points to your Firebase Service Account JSON file, or configure your local environment with Firebase project defaults.

---

### Frontend Setup

**Prerequisites:** Flutter SDK (Dart `^3.11.4`), Android Studio, Android device/emulator

```bash
# 1. Navigate to frontend directory
cd safescan_frontend

# 2. Install dependencies
flutter pub get

# 3. (Optional) Run tests
flutter test

# 4. Run application
flutter run
```

- **Android Emulator:** Connects to the host backend automatically via `http://10.0.2.2:8000`.
- **Physical Device:** Update `baseUrl` in `lib/services/api_service.dart` with your development computer's local Wi-Fi IP address (e.g., `http://192.168.1.50:8000`).

---

## Dependencies

### Backend (`safescan_backend/requirements.txt`)

| Package | Purpose |
|---|---|
| `fastapi` | High-performance Python web framework for REST APIs |
| `uvicorn[standard]` | ASGI server for production and development |
| `python-multipart` | Multipart file upload streaming for `.apk` binaries |
| `androguard==3.3.5` | Static DEX decompilation, manifest inspection, API call mapping |
| `numpy` | Feature vector array construction and indexing |
| `pandas` | Feature mapping table parsing |
| `scikit-learn` | TF-IDF vectorizers and Logistic Regression classifiers |
| `lightgbm` | Gradient-boosted decision tree classifier for APK malware |
| `joblib` | Model and vectorizer artifact deserialization |
| `firebase-admin` | Firebase ID token verification and Cloud Firestore operations |
| `pytest` | Test framework for unit and integration testing |
| `httpx` | Synchronous and asynchronous HTTP test client |

### Frontend (`safescan_frontend/pubspec.yaml`)

| Package | Purpose |
|---|---|
| `flutter` | Flutter SDK framework |
| `http: ^1.6.0` | HTTP network communication with the FastAPI server |
| `file_picker: ^12.2.0` | Native file picker for selecting device APKs |
| `telephony: ^0.2.0` | Incoming SMS receiver for background auto-scan |
| `flutter_local_notifications: ^22.3.0` | Foreground and background system notification delivery |
| `permission_handler: ^12.0.1` | Runtime Android permission management (SMS, storage, notifications) |
| `shared_preferences: ^2.5.3` | Persistent local key-value store for app settings and toggles |
| `firebase_core: ^4.15.0` | Firebase platform core initialization |
| `firebase_auth: ^6.7.0` | User authentication (Email, Google, Guest) |
| `cloud_firestore: ^6.10.0` | Cloud database for real-time scan history synchronization |
| `flutter_launcher_icons: ^0.14.4` | Automated native launcher icon generation |
| `flutter_native_splash: ^2.4.7` | Pre-Flutter native splash screen configuration |

---

## Important Limitations & Security Notes

> **SafeScan provides automated machine learning risk indicators, not an absolute guarantee of application or message safety.**

- **Static Analysis Scope:** The APK scanner performs static bytecode and manifest inspection only. Dynamic payloads, runtime reflection, packed or heavily obfuscated code, and dynamically downloaded stages are outside its scope.
- **Dataset Boundaries:** The models reflect training distributions. Zero-day threats, new phishing templates, or novel malware patterns emerging after dataset collection may yield false negatives.
- **Operating Permissions:** Automated background SMS and APK features require explicit Android runtime permissions (Notification, SMS, Storage) which must be granted by the user.
- **Authentication Security:** The FastAPI backend enforces Firebase ID token verification on the history logging endpoint (`POST /scan/history`). Primary scan endpoints (`/scan`, `/scan/sms`, `/scan/url`) operate publicly for high availability on cloud hosting environments (such as Render) regardless of server-side ADC key configuration.
