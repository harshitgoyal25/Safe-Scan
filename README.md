# SafeScan

> **A machine-learning-powered Android cybersecurity application that screens APK files, SMS messages, and URLs for malicious content before you trust them.**

SafeScan is a full-stack mobile security tool built with a **Flutter** Android frontend and a **Python FastAPI** backend. Three fully independent ML-based scanners work together inside a single app, giving non-technical users a "calmer way to check what you receive."

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
5. [ML Models](#ml-models)
   - [APK Malware Detector](#apk-malware-detector)
   - [SMS Spam / Malicious Detector](#sms-spam--malicious-detector)
   - [URL Phishing Detector](#url-phishing-detector)
6. [Model Artifacts](#model-artifacts)
7. [API Reference](#api-reference)
8. [Frontend — Flutter Android](#frontend--flutter-android)
   - [lib/main.dart](#libmaindart)
   - [lib/screens/home_screen.dart](#libscreenshome_screendart)
   - [lib/screens/scan_screen.dart](#libscreensscan_screendart)
   - [lib/screens/result_screen.dart](#libscreensresult_screendart)
   - [lib/screens/sms_scan_screen.dart](#libscreenssms_scan_screendart)
   - [lib/screens/sms_result_screen.dart](#libscreenssms_result_screendart)
   - [lib/screens/url_scan_screen.dart](#libscreensurl_scan_screendart)
   - [lib/screens/url_result_screen.dart](#libscreensurl_result_screendart)
   - [lib/models/scan_result.dart](#libmodelsscan_resultdart)
   - [lib/services/api_service.dart](#libservicesapi_servicedart)
   - [lib/services/notification_service.dart](#libservicesnotification_servicedart)
   - [lib/services/sms_background_service.dart](#libservicessms_background_servicedart)
9. [Performance Metrics](#performance-metrics)
10. [Setup & Running](#setup--running)
    - [Backend Setup](#backend-setup)
    - [Frontend Setup](#frontend-setup)
11. [Dependencies](#dependencies)
12. [Important Limitations](#important-limitations)

---

## Project Overview

SafeScan provides three independent security scanners accessible from a single Android application:

| Scanner | Input | What it detects |
|---|---|---|
| **APK Scanner** | `.apk` file (upload) | Android malware via static analysis |
| **SMS Scanner** | Paste / type message text | Spam and malicious SMS messages |
| **URL Scanner** | Paste / type any URL | Phishing and malicious web links |

All three scanners share the same design pattern:
1. User provides input through the Flutter app.
2. The app sends the input to the FastAPI backend over HTTP.
3. The backend runs pre-trained ML models and returns a **classification**, **malicious probability**, and **detection threshold**.
4. The app displays the result with a visual risk indicator.

---

## High-Level Architecture

```
┌─────────────────────────────────┐        HTTP / JSON
│       Flutter Android App       │ ◄──────────────────────►  FastAPI Backend
│  (safescan_frontend/)           │                           (safescan_backend/)
│                                 │                           ┌───────────────┐
│  HomeScreen                     │  POST /scan               │  extractor.py │ → LightGBM
│  ├── ScanScreen   (APK)    ─────┼─────────────────────────► │  (APK model)  │
│  ├── SmsScanScreen (SMS)   ─────┼── POST /scan/sms ────────►│  sms_detector │ → LogReg
│  └── UrlScanScreen (URL)   ─────┼── POST /scan/url ────────►│  url_detector │ → LogReg
│                                 │  GET  /health             └───────────────┘
│  Background SMS auto-scan       │  Incoming SMS
│  SmsBackgroundService      ─────┼── POST /scan/sms ──► SMS Model ──► NotificationService
└─────────────────────────────────┘
```

The backend runs locally (or on a server). During Android emulator development the base URL is `http://10.0.2.2:8000` — the standard Android emulator alias for `localhost` on the host machine.

---

## Repository Structure

```
SafeScan/
├── safescan_backend/           # Python FastAPI backend
│   ├── app/
│   │   ├── main.py             # FastAPI app, all HTTP endpoints
│   │   ├── extractor.py        # APK static analysis + LightGBM prediction
│   │   ├── sms_detector.py     # SMS TF-IDF + Logistic Regression prediction
│   │   ├── url_detector.py     # URL TF-IDF + Logistic Regression prediction
│   │   └── url_extractor.py    # Legacy extractor; not used by current URL model
│   ├── models/
│   │   ├── apk_model/
│   │   │   ├── model.pkl           # Trained LightGBM classifier
│   │   │   ├── feature_names.csv   # All 24,833 original feature names
│   │   │   ├── selected_features.csv # 10,000 chi-square-selected features
│   │   │   └── config.json         # Model hyperparameters + threshold
│   │   ├── sms_model/
│   │   │   ├── sms_model.pkl           # Trained Logistic Regression classifier
│   │   │   ├── sms_word_vectorizer.pkl # Word-level TF-IDF vectorizer
│   │   │   └── sms_char_vectorizer.pkl # Character-level TF-IDF vectorizer
│   │   └── url_model/
│   │       ├── url_model.pkl           # Trained Logistic Regression classifier
│   │       ├── url_word_vectorizer.pkl # Word-level TF-IDF vectorizer
│   │       ├── url_char_vectorizer.pkl # Character-level TF-IDF vectorizer
│   │       └── config.json             # Model hyperparameters + threshold + test results
│   ├── test_extractor.py       # Manual test script for APK extractor
│   ├── test_sms_detector.py    # Manual test script for SMS detector
│   ├── test_url_detector.py    # Manual test script for URL detector
│   └── requirements.txt        # Python dependencies
│
└── safescan_frontend/          # Flutter Android application
    ├── lib/
    │   ├── main.dart                       # App entry point, theme, MaterialApp
    │   ├── models/
    │   │   └── scan_result.dart            # APK scan result data model
    │   ├── screens/
    │   │   ├── home_screen.dart            # Dashboard with scanner cards
    │   │   ├── scan_screen.dart            # APK file picker + scan trigger
    │   │   ├── result_screen.dart          # APK scan result display
    │   │   ├── sms_scan_screen.dart        # SMS text input + scan trigger
    │   │   ├── sms_result_screen.dart      # SMS scan result display
    │   │   ├── url_scan_screen.dart        # URL text input + scan trigger
    │   │   └── url_result_screen.dart      # URL scan result display
    │   └── services/
    │       ├── api_service.dart            # HTTP client for all three endpoints
    │       ├── notification_service.dart   # Local push notifications
    │       └── sms_background_service.dart # Incoming SMS listener + auto-scan
    └── pubspec.yaml            # Flutter dependencies
```

---

## Backend — Python FastAPI

### `app/main.py`

**The single entry point for the entire API.** Initialises a `FastAPI` application (`SafeScan API v1.0.0`) and wires up all HTTP routes. Also defines global input validation constants:

- `MAX_FILE_SIZE = 200 MB` — APK upload size limit
- `MAX_TEXT_LENGTH = 10,000 chars` — SMS / URL character limit

**Routes defined here:**

| Method | Path | Handler | Description |
|---|---|---|---|
| `GET` | `/` | `root()` | Returns API name, status, version |
| `GET` | `/health` | `health()` | Health check — returns `{"status": "healthy"}` |
| `POST` | `/scan` | `scan_apk()` | Accepts multipart `.apk` upload, streams it to a temp file, calls `predict_apk()`, returns result JSON |
| `POST` | `/scan/sms` | `scan_sms()` | Accepts `{"message": "..."}` JSON body, calls `predict_sms()`, returns result JSON |
| `POST` | `/scan/url` | `scan_url()` | Accepts `{"url": "..."}` JSON body, calls `predict_url()`, returns result JSON |

The APK endpoint writes the uploaded file into a temporary file in 1 MB chunks to cap memory use, then deletes the temp file in a `finally` block regardless of success or failure.

---

### `app/extractor.py`

**APK static analysis and LightGBM prediction engine.** This is the most complex backend file.

**At module load time** (once, when the server starts):
- Loads `model.pkl` (the trained LightGBM binary classifier)
- Loads `feature_names.csv` (all 24,833 original feature names) into `ALL_FEATURES`
- Loads `selected_features.csv` (the 10,000 chi-square-selected features) into `SELECTED_FEATURES`
- Builds `FEATURE_INDEX` — a fast `{feature_name: index}` lookup dictionary
- Builds `SELECTED_INDICES` — a NumPy array of the 10,000 integer indices into `ALL_FEATURES`
- Loads `config.json` and extracts the production classification threshold (`0.52`) via `find_threshold()`

**Key functions:**

| Function | Purpose |
|---|---|
| `normalize_permission(p)` | Strips `android.permission.` prefix, returns `Permission::READ_SMS` style key |
| `normalize_intent(i)` | Strips `android.intent.action.` prefix, returns `Intent::MAIN` style key |
| `normalize_api(class, method)` | Returns `APICall::Lclass.method()` style key matching MH-100K vocabulary |
| `extract_permissions(apk)` | Uses AndroGuard's `apk.get_permissions()` to extract all declared permissions |
| `extract_intents(apk)` | Iterates activities, services, receivers, providers and extracts intent-filter actions |
| `extract_api_calls(dx)` | Iterates every method in the DEX analysis, follows cross-references (`xref_to`), collects all called API names |
| `extract_full_feature_vector(apk_path)` | Calls AndroGuard `AnalyzeAPK()`, aggregates all three feature sets, encodes as a 24,833-element binary `int8` NumPy vector. Returns `(vector, matched_count)` |
| `extract_model_features(apk_path)` | Calls `extract_full_feature_vector`, then slices it with `SELECTED_INDICES` to produce the 10,000-element vector the model expects |
| `predict_apk(apk_path)` | Wraps everything: extracts features, calls `MODEL.predict_proba()`, applies threshold, returns `{prediction, probability, threshold, matched_features, active_features}` |

**Feature naming convention** (must match MH-100K training vocabulary exactly):
- Permissions → `Permission::CAMERA`
- Intents → `Intent::MAIN`
- API calls → `APICall::Landroid/telephony/SmsManager.sendTextMessage()`

---

### `app/sms_detector.py`

**SMS classification using dual TF-IDF + Logistic Regression.**

**At module load time:**
- Loads `sms_model.pkl` (Logistic Regression classifier)
- Loads `sms_word_vectorizer.pkl` (word-level TF-IDF, 1–2 grams)
- Loads `sms_char_vectorizer.pkl` (character-level TF-IDF, 3–5 grams)
- Sets `THRESHOLD = 0.40` (hardcoded production threshold)

**`predict_sms(message: str) -> dict`:**
1. Validates that `message` is a non-empty string
2. Transforms the message with `word_vectorizer` → sparse word features
3. Transforms the message with `char_vectorizer` → sparse char features
4. Horizontally stacks both sparse matrices with `scipy.sparse.hstack` (exactly as done during training)
5. Calls `model.predict_proba(combined)` and extracts class-1 (malicious) probability
6. Applies threshold: probability >= 0.40 → `"Malicious"`, else `"Benign"`
7. Returns `{prediction, probability, threshold, word_features, char_features, total_features}`

---

### `app/url_detector.py`

**URL classification using dual TF-IDF + Logistic Regression.** Structurally identical to `sms_detector.py` but for URLs.

**At module load time:**
- Loads `url_model.pkl`, `url_word_vectorizer.pkl`, `url_char_vectorizer.pkl`
- Sets `THRESHOLD = 0.41`

**`predict_url(url: str) -> dict`:**
1. Validates URL string, trims whitespace, enforces 10,000-character limit
2. Transforms with word-level TF-IDF (URL-aware tokenisation, 1–2 grams, up to 100,000 features)
3. Transforms with character-level TF-IDF (3–5 grams, up to 100,000 features)
4. Stacks both — up to 200,000 combined sparse features
5. Runs `model.predict_proba()`, applies threshold 0.41 → `"Malicious"` or `"Benign"`
6. Returns `{prediction, probability, threshold, word_features, char_features, total_features}`

---

### `app/url_extractor.py` _(Legacy — not used by the current URL model)_

`url_extractor.py` is retained only as a legacy/reference file from an earlier URL modelling approach. **It is not called during current URL training or inference.**

The current production URL pipeline is entirely TF-IDF based:

```
Raw URL
   ↓
Word TF-IDF  +  Character TF-IDF
   ↓
Logistic Regression
   ↓
Probability  →  Threshold 0.41  →  Malicious / Benign
```

The file implements a 78-feature lexical/structural extractor based on the ISCX-URL2016 feature definition (token lengths, digit/letter/entropy counts, structural flags, sensitive keyword detection, etc.) and is preserved for reference only.

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
| **Production threshold** | **0.52** (chosen to maximise precision while keeping recall >= 95%) |
| **Data split** | Stratified 70% train / 15% validation / 15% test, `random_state=42` |
| **Final model trained on** | Train + Validation combined |

**How it works at inference:** An APK is decompiled using AndroGuard. Permissions, intent filters, and all cross-referenced API calls are extracted and encoded as a 24,833-dimensional binary vector. The vector is sliced to the 10,000 chi-square-selected indices and fed into LightGBM. If the malicious probability >= 0.52, the APK is classified as `"Malicious"`.

---

### SMS Spam / Malicious Detector

| Property | Value |
|---|---|
| **Dataset** | UCI SMS Spam Collection |
| **Original dataset size** | 5,574 messages (4,827 ham + 747 spam) |
| **After cleaning** | 5,158 messages (4,516 benign + 642 malicious/spam) |
| **Features** | Word-level TF-IDF (1–2 grams) + Character-level TF-IDF (3–5 grams), combined sparse matrix |
| **Algorithm** | Logistic Regression (`C=2.0`, `class_weight=balanced`) |
| **Production threshold** | **0.40** |
| **Data split** | Stratified 70% train / 15% validation / 15% test, `random_state=42` |
| **Final model trained on** | Train + Validation combined |

**Why dual TF-IDF?** Word-level TF-IDF captures semantics and known spam phrases. Character-level TF-IDF captures obfuscated spellings, punctuation patterns, and subword signals that spammers use to evade word-level filters. Combining both yields stronger coverage.

---

### URL Phishing Detector

| Property | Value |
|---|---|
| **Dataset** | `URL dataset.csv` — a binary legitimate/phishing URL dataset containing 450,176 URLs (345,738 legitimate + 104,438 phishing; 0 missing values, 0 duplicates) |
| **Features** | Word-level TF-IDF with URL-aware tokenisation (1–2 grams, up to 100,000 features) + Character-level TF-IDF (3–5 grams, up to 100,000 features) = **up to 200,000 combined features** |
| **Algorithm** | Logistic Regression (`C=2.0`, `class_weight=balanced`, `solver=liblinear`, `max_iter=2000`) |
| **Production threshold** | **0.41** (chosen by best F1 on validation set) |
| **Data split** | Stratified 70% train / 15% validation / 15% test, `random_state=42` |
| **Final model trained on** | Train + Validation combined |

**URL-aware tokenisation:** The word-level vectorizer uses `token_pattern=[^/\s]+` instead of the default regex, so URL path segments are treated as individual tokens rather than being split at every punctuation mark. This preserves domain names, file paths, and query strings as meaningful units.

---

## Model Artifacts

All serialised artifacts are stored under `safescan_backend/models/`.

| File | Format | Description |
|---|---|---|
| `apk_model/model.pkl` | pickle / joblib | Trained LightGBM binary classifier (~1.9 MB) |
| `apk_model/feature_names.csv` | CSV, 1 column | All 24,833 MH-100K feature names in training order |
| `apk_model/selected_features.csv` | CSV, 1 column | The 10,000 chi-square-selected feature names in model order |
| `apk_model/config.json` | JSON | Hyperparameters, split config, threshold (0.52) |
| `sms_model/sms_model.pkl` | joblib | Trained Logistic Regression SMS classifier (~485 KB) |
| `sms_model/sms_word_vectorizer.pkl` | joblib | Fitted word-level TF-IDF vectorizer (~398 KB) |
| `sms_model/sms_char_vectorizer.pkl` | joblib | Fitted char-level TF-IDF vectorizer (~1.7 MB) |
| `url_model/url_model.pkl` | joblib | Trained Logistic Regression URL classifier (~1.6 MB) |
| `url_model/url_word_vectorizer.pkl` | joblib | Fitted word-level TF-IDF vectorizer (~4.9 MB) |
| `url_model/url_char_vectorizer.pkl` | joblib | Fitted char-level TF-IDF vectorizer (~3.4 MB) |
| `url_model/config.json` | JSON | Hyperparameters, split config, threshold (0.41), test results |

> **Note:** The `sms_model` does not have a separate `config.json`; its threshold (0.40) is hardcoded in `sms_detector.py`.

---

## API Reference

All endpoints served by `uvicorn` at `http://localhost:8000` by default.

### `GET /`
Returns basic API info.

```json
{ "name": "SafeScan API", "status": "running", "version": "1.0.0" }
```

### `GET /health`
Health check for load balancers or monitoring.

```json
{ "status": "healthy" }
```

### `POST /scan` — APK Analysis

**Request:** `multipart/form-data` with field `file` containing the `.apk` binary.

**Constraints:** File must end in `.apk`, max 200 MB, must not be empty.

**Response:**
```json
{
  "filename": "example.apk",
  "prediction": "Malicious",
  "probability": 0.8741,
  "threshold": 0.52,
  "matched_features": 312,
  "active_features": 87
}
```

| Field | Description |
|---|---|
| `prediction` | `"Malicious"` or `"Benign"` |
| `probability` | Malicious probability in [0.0, 1.0] |
| `threshold` | Decision boundary used (0.52) |
| `matched_features` | Features extracted from the APK that exist in the 24,833-feature vocabulary |
| `active_features` | Of those, how many were in the 10,000 selected features given to the model |

**Error codes:** `400` (not APK / empty), `413` (too large), `500` (analysis failed / invalid APK)

---

### `POST /scan/sms` — SMS Analysis

**Request:**
```json
{ "message": "Congratulations! You've won a $1000 gift card. Click here to claim." }
```

**Constraints:** Non-empty string, max 10,000 characters.

**Response:**
```json
{
  "prediction": "Malicious",
  "probability": 0.9312,
  "threshold": 0.40
}
```

**Error codes:** `400` (empty / not string), `413` (too long), `500` (analysis failed)

---

### `POST /scan/url` — URL Analysis

**Request:**
```json
{ "url": "http://totally-not-paypal.ru/login/verify" }
```

**Constraints:** Non-empty string, max 10,000 characters.

**Response:**
```json
{
  "url": "http://totally-not-paypal.ru/login/verify",
  "prediction": "Malicious",
  "probability": 0.9874,
  "threshold": 0.41
}
```

**Error codes:** `400` (empty / not string), `413` (too long), `500` (analysis failed)

---

## Frontend — Flutter Android

Built with Flutter (Dart SDK `^3.11.4`), Material Design 3, dark theme. Primary color: teal `#0F766E`. Font: Inter.

### `lib/main.dart`

**App entry point.** Calls `WidgetsFlutterBinding.ensureInitialized()`, initialises `NotificationService`, then starts the Flutter app. Defines the global `MaterialApp` with the dark Material 3 theme, custom teal color scheme, card styles, input decoration, button styles, and sets `HomeScreen` as the initial route.

---

### `lib/screens/home_screen.dart`

**The main dashboard screen users land on.** Contains:
- A hero tagline and subtitle describing the app
- A decorative teal "Your first line of defense" banner
- An **Automatic SMS Protection** toggle that, when enabled, calls `SmsBackgroundService().init()` to register a background SMS listener
- Three `_ScannerCard` tappable cards navigating to `ScanScreen`, `SmsScanScreen`, and `UrlScanScreen`
- A disclaimer footer reminding users results are automated indicators, not guarantees
- An About dialog accessible from the AppBar

The private `_ScannerCard` widget renders an icon, title, and subtitle in a styled `InkWell` card with a chevron arrow.

---

### `lib/screens/scan_screen.dart`

**APK upload and scan trigger screen.** Uses `file_picker` (`FileType.custom`, extension `apk`) to let the user browse their device storage for an APK. Once selected, the filename is shown in a card. The "Scan APK" button calls `ApiService.scanApk()`, shows a `CircularProgressIndicator` while waiting, and then pushes `ResultScreen` with the parsed `ScanResult`.

---

### `lib/screens/result_screen.dart`

**APK scan result display screen.** Renders:
- A `CircularProgressIndicator` with the malicious probability as its fill value, with an overlaid status icon (warning vs verified)
- The prediction label in colour (red = Malicious, green = Benign)
- A description of the result
- The APK filename
- A "Threat likelihood" card showing the probability percentage and risk tier:
  - >= 75% → "High threat likelihood"
  - >= 40% → "Moderate threat likelihood"
  - < 40% → "Low threat likelihood"
- An "Analysis Details" card showing `matched_features` and `active_features`
- A "Scan Another APK" button that pops back to `ScanScreen`

---

### `lib/screens/sms_scan_screen.dart`

**SMS text input and scan trigger screen.** A multi-line `TextField` for the user to paste or type a message, plus a "Scan Message" button that calls `ApiService.scanSms()` and pushes `SmsResultScreen`.

---

### `lib/screens/sms_result_screen.dart`

**SMS scan result display screen.** Shows the prediction (Malicious / Benign), probability percentage, and threshold used. Visual styling mirrors `ResultScreen` — red for malicious, green for benign.

---

### `lib/screens/url_scan_screen.dart`

**URL input and scan trigger screen.** A single-line `TextField` for URL input and a "Scan URL" button that calls `ApiService.scanUrl()` and pushes `UrlResultScreen`.

---

### `lib/screens/url_result_screen.dart`

**URL scan result display screen.** Shows the classification, probability, and threshold. Also displays the scanned URL back to the user for confirmation.

---

### `lib/models/scan_result.dart`

**Data model for APK scan results.** A simple Dart class with fields:

| Field | Type | Source |
|---|---|---|
| `filename` | `String` | APK file name |
| `prediction` | `String` | `"Malicious"` or `"Benign"` |
| `probability` | `double` | Malicious probability [0–1] |
| `threshold` | `double` | Classification threshold used |
| `matchedFeatures` | `int` | Features matched in the 24,833 vocabulary |
| `activeFeatures` | `int` | Features active in the 10,000-feature model input |

Convenience getters: `isMalware` (bool, true when `prediction == "Malware"` — note the backend now returns `"Malicious"`, so this getter will need updating if the model string changes) and `probabilityPercent` (probability × 100).

---

### `lib/services/api_service.dart`

**HTTP client for all three backend endpoints.** Uses the `http` package.

- `baseUrl = 'http://10.0.2.2:8000'` — Android emulator loopback for localhost
- `scanApk(File apkFile)` — sends a `multipart/form-data` POST to `/scan`
- `scanSms(String message)` — sends a JSON POST to `/scan/sms`
- `scanUrl(String url)` — sends a JSON POST to `/scan/url`

All methods throw an `Exception` with the raw response body on non-200 status codes.

> **For physical device testing:** change `baseUrl` to the host machine's LAN IP address (e.g. `http://192.168.1.x:8000`).

---

### `lib/services/notification_service.dart`

**Singleton Android local push notification service.** Wraps `flutter_local_notifications`.

- `init()` — initialises with `@mipmap/ic_launcher` icon; handles notification tap callbacks
- `showSmsScanResult(sender, isMalicious)` — fires a high-priority notification on the `safescan_sms_channel` channel:
  - Malicious: title "Malicious SMS Detected", body names the sender
  - Safe: title "Safe SMS Received", body names the sender

---

### `lib/services/sms_background_service.dart`

**Automatic incoming SMS scanner.** Uses the `telephony` package to register a foreground and background SMS listener.

- `backgroundMessageHandler(SmsMessage)` — annotated `@pragma('vm:entry-point')` so Flutter can invoke it from a background isolate. Initialises `NotificationService`, calls `ApiService.scanSms()` with the message body, and fires a notification with the result.
- `SmsBackgroundService.init()` — requests phone + SMS permissions, then registers `backgroundMessageHandler` for both `onNewMessage` (foreground) and `onBackgroundMessage` (background isolate).

When Automatic SMS Protection is enabled and the required permissions are granted, SafeScan attempts to scan incoming SMS messages in the background and displays the classification through a local notification. Background SMS behaviour depends on Android version, device manufacturer, and battery optimisation settings.

---

## Performance Metrics

All metrics are evaluated on the **held-out 15% test split** (never seen during training or threshold selection).

| Scanner | Accuracy | Balanced Accuracy | ROC-AUC | PR-AUC |
|---|---|---|---|---|
| APK Malware | **96.91%** | **95.74%** | **98.68%** | **90.83%** |
| SMS Spam / Malicious | **99.35%** | **98.74%** | **99.86%** | **99.41%** |
| URL Phishing | **99.83%** | **99.75%** | **99.98%** | **99.96%** |

> **Interpretation note:** These metrics represent performance on the respective held-out test sets and should not be interpreted as guaranteed real-world detection rates. Dataset distribution, concept drift, previously unseen malware/phishing techniques, and adversarial inputs can affect real-world performance. The URL model's high ROC-AUC reflects the training distribution; out-of-distribution URLs (e.g. newly registered domains, obfuscated paths) may produce false positives or false negatives.

### Model Decision Thresholds

| Detector | Model | Feature representation | Threshold |
|---|---|---|---|
| APK | LightGBM | 10,000 selected static features | **0.52** |
| SMS | Logistic Regression | Word + character TF-IDF | **0.40** |
| URL | Logistic Regression | Word + character TF-IDF | **0.41** |

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

# 2. Create a virtual environment (recommended)
python -m venv .venv

# On Windows:
.venv\Scripts\activate
# On macOS/Linux:
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Start the FastAPI server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`. Interactive Swagger docs at `http://localhost:8000/docs`.

> **Important:** AndroGuard (`androguard==3.3.5`) is required for APK scanning. If you only need SMS/URL scanning, the `/scan` (APK) endpoint will fail at runtime, but the other two endpoints will work normally.

---

### Frontend Setup

**Prerequisites:** Flutter SDK (Dart `^3.11.4`), Android Studio, Android emulator or physical device

```bash
# 1. Navigate to frontend directory
cd safescan_frontend

# 2. Get dependencies
flutter pub get

# 3. Run on connected Android emulator or device
flutter run
```

**Android Emulator:** No URL change needed — `10.0.2.2:8000` maps to the host machine's localhost automatically.

**Physical Android Device:** Edit `lib/services/api_service.dart` and change `baseUrl` to your machine's IP on the same local network:
```dart
static const String baseUrl = 'http://192.168.x.x:8000';
```

---

## Dependencies

### Backend (`requirements.txt`)

| Package | Purpose |
|---|---|
| `fastapi` | Web framework for the REST API |
| `uvicorn[standard]` | ASGI server to run FastAPI |
| `python-multipart` | Enables file upload parsing in FastAPI |
| `androguard==3.3.5` | APK static analysis (decompilation, permissions, API call extraction) |
| `numpy` | Binary feature vector construction |
| `pandas` | Feature CSV loading and DataFrame construction for LightGBM |
| `scikit-learn` | TF-IDF vectorizers, Logistic Regression, chi-square selection |
| `lightgbm` | Gradient-boosted tree classifier for APK detection |
| `joblib` | Model artifact serialisation/deserialisation |

### Frontend (`pubspec.yaml`)

| Package | Purpose |
|---|---|
| `http: ^1.6.0` | HTTP requests to the FastAPI backend |
| `file_picker: ^12.2.0` | Native file browser for APK selection |
| `telephony: ^0.2.0` | Incoming SMS listener for background auto-scan |
| `flutter_local_notifications: ^22.3.0` | Local push notifications for background SMS results |
| `permission_handler: ^13.0.2` | Runtime permission requests (SMS, phone) |

---

## Important Limitations

> **SafeScan results should be treated as an indication of potential maliciousness, not an absolute guarantee of safety.**

- **APK scanner performs static analysis only.** It does not run the APK. Dynamic behaviours, obfuscated code, or runtime-downloaded payloads are outside its scope.
- **All three models are trained on fixed datasets.** New malware families, phishing campaigns, or spam techniques that emerged after the training data was collected may not be detected.
- **False positives and false negatives exist** in all three models. Even at 99%+ accuracy, at scale some samples will be misclassified.
- **The SMS background scanner requires SMS read permissions.** Users must grant these explicitly. The feature is opt-in via the toggle on the home screen.
- **The backend URL is hardcoded to `10.0.2.2:8000`** for emulator use. Production deployment requires configuring a real server address.
- **No authentication is implemented on the API.** Do not expose the backend publicly without adding appropriate security controls.
