from io import BytesIO

from fastapi.testclient import TestClient

from app import main


client = TestClient(main.app)


def auth_headers(monkeypatch):
    main.app.dependency_overrides[main.current_user_id] = lambda: "test-user"
    monkeypatch.setattr(main, "FIRESTORE", object())
    return {"Authorization": "Bearer test-token"}


def test_scan_requires_authentication():
    response = client.post("/scan/sms", json={"message": "hello"})
    assert response.status_code in {401, 503}


def test_invalid_token_is_rejected(monkeypatch):
    main.app.dependency_overrides.clear()
    monkeypatch.setitem(main.firebase_admin._apps, "test", object())
    monkeypatch.setattr(main.auth, "verify_id_token", lambda token: (_ for _ in ()).throw(ValueError()))
    response = client.post(
        "/scan/sms",
        json={"message": "hello"},
        headers={"Authorization": "Bearer invalid"},
    )
    assert response.status_code == 401


def test_empty_sms_is_rejected(monkeypatch):
    response = client.post(
        "/scan/sms",
        json={"message": ""},
        headers=auth_headers(monkeypatch),
    )
    assert response.status_code == 400


def test_empty_apk_is_rejected(monkeypatch):
    response = client.post(
        "/scan",
        files={"file": ("empty.apk", BytesIO(b""), "application/vnd.android.package-archive")},
        headers=auth_headers(monkeypatch),
    )
    assert response.status_code == 400


def test_history_requires_authentication():
    main.app.dependency_overrides.clear()
    response = client.post(
        "/scan/history",
        json={"scan_type": "apk", "input_label": "APK", "input_value": "a.apk", "result": {}},
    )
    assert response.status_code in {401, 503}