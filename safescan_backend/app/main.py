from pathlib import Path
import tempfile

from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel

from app.extractor import predict_apk
from app.sms_detector import predict_sms
from app.url_detector import predict_url


app = FastAPI(
    title="SafeScan API",
    description="Android APK, SMS, and URL security detection API",
    version="1.0.0",
)


# ============================================================
# SETTINGS
# ============================================================

MAX_FILE_SIZE = 200 * 1024 * 1024
MAX_TEXT_LENGTH = 10000


# ============================================================
# REQUEST MODELS
# ============================================================

class SMSRequest(BaseModel):
    message: str


class URLRequest(BaseModel):
    url: str


# ============================================================
# ROOT
# ============================================================

@app.get("/")
def root():
    return {
        "name": "SafeScan API",
        "status": "running",
        "version": "1.0.0",
    }


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
def health():
    return {
        "status": "healthy",
    }


# ============================================================
# APK SCANNING
# ============================================================

@app.post("/scan")
async def scan_apk(file: UploadFile = File(...)):

    if not file.filename:
        raise HTTPException(
            status_code=400,
            detail="No filename provided.",
        )

    filename = Path(file.filename).name

    if not filename.lower().endswith(".apk"):
        raise HTTPException(
            status_code=400,
            detail="Only APK files are supported.",
        )

    temp_path = None
    total_size = 0

    try:
        with tempfile.NamedTemporaryFile(
            suffix=".apk",
            delete=False,
        ) as temp_file:

            temp_path = Path(temp_file.name)

            while True:
                chunk = await file.read(1024 * 1024)

                if not chunk:
                    break

                total_size += len(chunk)

                if total_size > MAX_FILE_SIZE:
                    raise HTTPException(
                        status_code=413,
                        detail=(
                            "APK file is too large. "
                            "Maximum size is 200 MB."
                        ),
                    )

                temp_file.write(chunk)

        if total_size == 0:
            raise HTTPException(
                status_code=400,
                detail="The uploaded APK is empty.",
            )

        result = predict_apk(temp_path)

        return {
            "filename": filename,
            "prediction": result["prediction"],
            "probability": result["probability"],
            "threshold": result["threshold"],
            "matched_features": result["matched_features"],
            "active_features": result["active_features"],
        }

    except HTTPException:
        raise

    except Exception:
        raise HTTPException(
            status_code=500,
            detail=(
                "APK analysis failed. "
                "The file may be invalid or unsupported."
            ),
        )

    finally:
        if (
            temp_path is not None
            and temp_path.exists()
        ):
            try:
                temp_path.unlink()
            except Exception:
                pass

        await file.close()


# ============================================================
# SMS SCANNING
# ============================================================

@app.post("/scan/sms")
async def scan_sms(request: SMSRequest):

    message = request.message

    if not message or not message.strip():
        raise HTTPException(
            status_code=400,
            detail="SMS message cannot be empty.",
        )

    if len(message) > MAX_TEXT_LENGTH:
        raise HTTPException(
            status_code=413,
            detail="SMS message is too long.",
        )

    try:
        result = predict_sms(message)

        return {
            "prediction": result["prediction"],
            "probability": result["probability"],
            "threshold": result["threshold"],
        }

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e),
        )

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="SMS analysis failed.",
        )


# ============================================================
# URL SCANNING
# ============================================================

@app.post("/scan/url")
async def scan_url(request: URLRequest):

    url = request.url.strip()

    if not url:
        raise HTTPException(
            status_code=400,
            detail="URL cannot be empty.",
        )

    if len(url) > MAX_TEXT_LENGTH:
        raise HTTPException(
            status_code=413,
            detail="URL is too long.",
        )

    try:
        result = predict_url(url)

        return {
            "url": url,
            "prediction": result["prediction"],
            "probability": result["probability"],
            "threshold": result["threshold"],
        }

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e),
        )

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="URL analysis failed.",
        )