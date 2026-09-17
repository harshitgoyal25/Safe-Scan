from io import BytesIO

from fastapi.testclient import TestClient

from app import main


client = TestClient(main.app)


# ---------------------------------------------------------------------------
# Helper: override current_user_id for /scan/history (still requires auth)
# ---------------------------------------------------------------------------

def _history_auth_headers(monkeypatch):
    main.app.dependency_overrides[main.current_user_id] = lambda: "test-user"
    monkeypatch.setattr(main, "FIRESTORE", object())
    return {"Authorization": "Bearer test-token"}


# ---------------------------------------------------------------------------
# Scan endpoints — open (no auth required after security rollback)
# ---------------------------------------------------------------------------

def test_sms_scan_works_without_token():
    """Scan endpoints must accept requests without an Authorization header."""
    response = client.post("/scan/sms", json={"message": "hello"})
    # 200 = scan ran; 500 = model loaded but something unexpected; both mean auth passed
    assert response.status_code in {200, 500}


def test_empty_sms_is_rejected():
    response = client.post("/scan/sms", json={"message": ""})
    assert response.status_code == 400


def test_empty_apk_is_rejected():
    response = client.post(
        "/scan",
        files={"file": ("empty.apk", BytesIO(b""), "application/vnd.android.package-archive")},
    )
    assert response.status_code == 400


# ---------------------------------------------------------------------------
# /scan/history — still requires a valid Firebase token
# ---------------------------------------------------------------------------

def test_history_requires_authentication():
    main.app.dependency_overrides.clear()
    response = client.post(
        "/scan/history",
        json={"scan_type": "apk", "input_label": "APK", "input_value": "a.apk", "result": {}},
    )
    assert response.status_code in {401, 503}
