from __future__ import annotations

import json

import app.notification_smoke as notification_smoke
from app.services.notification_delivery_service import (
    NotificationChannelDeliveryResult,
    NotificationDeliveryReport,
)


def test_notification_smoke_prints_delivery_status(tmp_path, monkeypatch, capsys):
    payload = {
        "title": "Smoke notification",
        "body": "Body for smoke test",
        "notification_type": "report_ready",
        "priority": "normal",
        "email_address": "patient@example.com",
        "devices": [
            {
                "platform": "android",
                "device_token": "android-token-123",
                "device_label": "Mi 10",
            }
        ],
    }
    payload_file = tmp_path / "notification.json"
    payload_file.write_text(json.dumps(payload), encoding="utf-8")

    captured: dict[str, object] = {}

    class FakeService:
        def __init__(self, settings):
            captured["settings"] = settings

        def dispatch(self, *, notification, preferences, device_tokens):
            captured["notification"] = notification
            captured["preferences"] = preferences
            captured["device_tokens"] = device_tokens
            return NotificationDeliveryReport(
                push=NotificationChannelDeliveryResult(
                    channel="push",
                    provider="webhook",
                    attempted=True,
                    delivered=True,
                    target_count=1,
                    delivered_count=1,
                ),
                email=NotificationChannelDeliveryResult(
                    channel="email",
                    provider="smtp",
                    attempted=True,
                    delivered=True,
                    target_count=1,
                    delivered_count=1,
                ),
            )

    monkeypatch.setattr(notification_smoke, "NotificationDeliveryService", FakeService)

    exit_code = notification_smoke.main(["--payload", str(payload_file)])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "push_provider=webhook" in output
    assert "email_provider=smtp" in output
    assert captured["notification"].title == "Smoke notification"
    assert len(captured["device_tokens"]) == 1


def test_notification_smoke_requires_external_provider(tmp_path, monkeypatch, capsys):
    payload = {
        "title": "Smoke notification",
        "body": "Body for smoke test",
        "notification_type": "report_ready",
        "priority": "normal",
        "email_address": "patient@example.com",
        "devices": [
            {
                "platform": "android",
                "device_token": "android-token-123",
            }
        ],
    }
    payload_file = tmp_path / "notification.json"
    payload_file.write_text(json.dumps(payload), encoding="utf-8")

    class FakeService:
        def __init__(self, settings):
            self.settings = settings

        def dispatch(self, *, notification, preferences, device_tokens):
            return NotificationDeliveryReport(
                push=NotificationChannelDeliveryResult(
                    channel="push",
                    provider="log_only",
                    attempted=True,
                    delivered=False,
                    target_count=1,
                ),
                email=NotificationChannelDeliveryResult(
                    channel="email",
                    provider="log_only",
                    attempted=True,
                    delivered=False,
                    target_count=1,
                ),
            )

    monkeypatch.setattr(notification_smoke, "NotificationDeliveryService", FakeService)

    exit_code = notification_smoke.main(
        [
            "--payload",
            str(payload_file),
            "--require-external-provider",
        ]
    )

    assert exit_code == 4
    output = capsys.readouterr().out
    assert "external_provider_required=true" in output
