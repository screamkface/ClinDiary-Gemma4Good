from __future__ import annotations

from uuid import uuid4

import httpx

import app.services.notification_delivery_service as notification_delivery_service
from app.core.config import Settings
from app.models.base import utcnow
from app.models.enums import NotificationPriority, NotificationType
from app.models.notification import Notification
from app.models.notification_device_token import NotificationDeviceToken
from app.models.notification_preference import NotificationPreference


def _notification(patient_id):
    return Notification(
        id=uuid4(),
        patient_id=patient_id,
        notification_type=NotificationType.REPORT_READY,
        title="Test",
        body="Messaggio di prova",
        priority=NotificationPriority.NORMAL,
        dedupe_key=f"smoke-{uuid4()}",
        is_active=True,
        created_at=utcnow(),
    )


def _device_token(patient_id, platform="android"):
    return NotificationDeviceToken(
        id=uuid4(),
        patient_id=patient_id,
        platform=platform,
        device_token=f"token-{uuid4()}",
        device_label="Mi 10",
        active=True,
        last_seen_at=utcnow(),
    )


def test_dispatch_returns_report_for_log_only_channels():
    patient_id = uuid4()
    service = notification_delivery_service.NotificationDeliveryService(
        Settings(
            notification_push_provider="log_only",
            notification_email_provider="log_only",
        )
    )

    report = service.dispatch(
        notification=_notification(patient_id),
        preferences=NotificationPreference(
            patient_id=patient_id,
            push_enabled=True,
            email_enabled=True,
            email_address="patient@example.com",
        ),
        device_tokens=[_device_token(patient_id)],
    )

    assert report.push is not None
    assert report.push.provider == "log_only"
    assert report.push.attempted is True
    assert report.push.delivered is False
    assert report.push.error is None
    assert report.email is not None
    assert report.email.provider == "log_only"
    assert report.email.attempted is True
    assert report.email.delivered is False
    assert report.email.error is None
    assert report.attempted is True
    assert report.delivered is False
    assert report.has_errors is False


def test_dispatch_returns_report_for_webhook_and_smtp_success(monkeypatch):
    patient_id = uuid4()
    notification = _notification(patient_id)
    captured: dict[str, object] = {}

    def fake_post(url, *args, **kwargs):
        captured["push_url"] = url
        captured["push_payload"] = kwargs["json"]
        request = httpx.Request("POST", url)
        return httpx.Response(200, request=request)

    monkeypatch.setattr(notification_delivery_service.httpx, "post", fake_post)

    class FakeSMTP:
        def __init__(self, host, port, timeout):
            captured["smtp"] = {"host": host, "port": port, "timeout": timeout}

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def starttls(self):
            captured["starttls"] = True

        def login(self, username, password):
            captured["login"] = (username, password)

        def send_message(self, message):
            captured["subject"] = message["Subject"]
            captured["to"] = message["To"]

    monkeypatch.setattr(notification_delivery_service.smtplib, "SMTP", FakeSMTP)

    service = notification_delivery_service.NotificationDeliveryService(
        Settings(
            notification_push_provider="webhook",
            notification_push_webhook_url="https://push.example/webhook",
            notification_email_provider="smtp",
            notification_email_from="no-reply@clindiary.local",
            smtp_host="smtp.example.com",
            smtp_port=587,
            smtp_use_tls=True,
        )
    )

    report = service.dispatch(
        notification=notification,
        preferences=NotificationPreference(
            patient_id=patient_id,
            push_enabled=True,
            email_enabled=True,
            email_address="patient@example.com",
        ),
        device_tokens=[_device_token(patient_id)],
    )

    assert report.push is not None
    assert report.push.provider == "webhook"
    assert report.push.delivered is True
    assert report.push.delivered_count == 1
    assert report.email is not None
    assert report.email.provider == "smtp"
    assert report.email.delivered is True
    assert report.email.delivered_count == 1
    assert captured["push_url"] == "https://push.example/webhook"
    assert captured["push_payload"]["notification_id"] == str(notification.id)
    assert captured["subject"] == "ClinDiary: Test"
    assert captured["to"] == "patient@example.com"
