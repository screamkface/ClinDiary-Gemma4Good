import os
from datetime import date
from io import BytesIO
from pathlib import Path

from reportlab.pdfgen import canvas
from sqlalchemy import select

import app.services.auth_service as auth_service
from app.models.clinical_document import ClinicalDocument
from app.models.dossier_share_link import DossierShareLink
from app.models.report import Report
from app.models.user import User


def _pdf_bytes(lines: list[str]) -> bytes:
    buffer = BytesIO()
    pdf = canvas.Canvas(buffer)
    y = 800
    for line in lines:
        pdf.drawString(72, y, line)
        y -= 20
    pdf.save()
    return buffer.getvalue()


def test_register_login_refresh_logout(client):
    register_response = client.post(
        "/api/v1/auth/register",
        json={"email": "new@example.com", "password": "StrongPass123!"},
    )

    assert register_response.status_code == 201
    register_body = register_response.json()
    assert register_body["user"]["email"] == "new@example.com"
    assert register_body["user"]["onboarding_completed"] is False
    assert register_body["user"]["ai_external_consent"] is False
    assert register_body["user"]["auth_provider"] == "password"

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "new@example.com", "password": "StrongPass123!"},
    )
    assert login_response.status_code == 200
    assert login_response.json()["user"]["auth_provider"] == "password"

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": login_response.json()["refresh_token"]},
    )
    assert refresh_response.status_code == 200
    assert refresh_response.json()["refresh_token"] != login_response.json()["refresh_token"]
    assert refresh_response.json()["user"]["auth_provider"] == "password"

    logout_response = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_response.json()["refresh_token"]},
    )
    assert logout_response.status_code == 200


def test_password_reset_flow(client):
    client.post(
        "/api/v1/auth/register",
        json={"email": "reset@example.com", "password": "StrongPass123!"},
    )

    request_response = client.post(
        "/api/v1/auth/password-reset/request",
        json={"email": "reset@example.com"},
    )
    assert request_response.status_code == 200
    preview_token = request_response.json()["preview_token"]
    assert preview_token

    confirm_response = client.post(
        "/api/v1/auth/password-reset/confirm",
        json={"token": preview_token, "new_password": "UpdatedPass123!"},
    )
    assert confirm_response.status_code == 200

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "reset@example.com", "password": "UpdatedPass123!"},
    )
    assert login_response.status_code == 200


def test_google_login_creates_session(client, monkeypatch):
    monkeypatch.setattr(
        auth_service.AuthService,
        "_verify_google_id_token",
        lambda self, token: {
            "email": "google-user@example.com",
            "sub": "google-subject-123",
            "email_verified": True,
        },
    )

    response = client.post(
        "/api/v1/auth/google",
        json={"id_token": "fake-google-token-1234567890-abcdef-abcdefghijklmnopqrstuvwxyz"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "google-user@example.com"
    assert body["user"]["onboarding_completed"] is False
    assert body["user"]["ai_external_consent"] is False
    assert body["user"]["auth_provider"] == "google"

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": body["refresh_token"]},
    )
    assert refresh_response.status_code == 200
    assert refresh_response.json()["user"]["auth_provider"] == "google"

    login_response = client.post(
        "/api/v1/auth/login",
        json={"email": "google-user@example.com", "password": "StrongPass123!"},
    )
    assert login_response.status_code == 401


def test_delete_account_removes_cloud_objects_and_revokes_access(client, auth_headers, db_session):
    today = date(2026, 3, 31)

    entry_response = client.post(
        "/api/v1/daily-entries",
        headers=auth_headers,
        json={"entry_date": today.isoformat(), "general_notes": "Test report deletion"},
    )
    assert entry_response.status_code == 201

    report_response = client.post(
        "/api/v1/reports/generate",
        headers=auth_headers,
        json={"report_type": "weekly_summary", "reference_date": today.isoformat()},
    )
    assert report_response.status_code == 201

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esame demo"},
        files={
            "file": (
                "esame-demo.pdf",
                _pdf_bytes(["Esame demo", "Glucosio 95 mg/dL 70-99"]),
                "application/pdf",
            )
        },
    )
    assert upload_response.status_code == 201

    share_link_response = client.post(
        "/api/v1/dossier/share-links",
        headers=auth_headers,
        json={"scope": "emergency", "label": "Medico", "expires_in_days": 3},
    )
    assert share_link_response.status_code == 201

    user = db_session.scalar(select(User).where(User.email == "patient@example.com"))
    assert user is not None
    document = db_session.scalar(select(ClinicalDocument).where(ClinicalDocument.patient_id == user.profile.id))
    report = db_session.scalar(select(Report).where(Report.patient_id == user.profile.id))
    share_link = db_session.scalar(select(DossierShareLink).where(DossierShareLink.patient_id == user.profile.id))
    assert document is not None
    assert report is not None
    assert share_link is not None

    storage_root = Path(os.environ["LOCAL_STORAGE_PATH"])
    assert (storage_root / document.file_url).exists()
    assert (storage_root / report.file_url).exists()
    assert (storage_root / share_link.object_key).exists()

    delete_response = client.post(
        "/api/v1/auth/account/delete",
        headers=auth_headers,
        json={"confirmation_text": "ELIMINA"},
    )

    assert delete_response.status_code == 200

    assert db_session.scalar(select(User).where(User.email == "patient@example.com")) is None
    assert not (storage_root / document.file_url).exists()
    assert not (storage_root / report.file_url).exists()
    assert not (storage_root / share_link.object_key).exists()

    access_after_delete = client.get("/api/v1/profile/me", headers=auth_headers)
    assert access_after_delete.status_code == 401


def test_delete_account_requires_confirmation_phrase(client, auth_headers):
    response = client.post(
        "/api/v1/auth/account/delete",
        headers=auth_headers,
        json={"confirmation_text": "NOPE"},
    )

    assert response.status_code == 400
