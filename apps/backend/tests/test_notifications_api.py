from __future__ import annotations

from app.api.v1 import notifications as notifications_api
from app.models.enums import NotificationPriority, NotificationType
from app.schemas.notifications import (
    NotificationDeliveryChannelResultResponse,
    NotificationDeliveryReportResponse,
)


def test_send_notification_test_delivery_endpoint(client, auth_headers, monkeypatch):
    captured: dict[str, object] = {}

    def fake_send_test_delivery(self, user, payload):
        captured["user_email"] = user.email
        captured["payload"] = payload
        return NotificationDeliveryReportResponse(
            push=NotificationDeliveryChannelResultResponse(
                channel="push",
                provider="webhook",
                attempted=True,
                delivered=True,
                target_count=1,
                delivered_count=1,
            ),
            email=NotificationDeliveryChannelResultResponse(
                channel="email",
                provider="smtp",
                attempted=True,
                delivered=False,
                target_count=1,
                error="SMTP non configurato",
            ),
            attempted=True,
            delivered=True,
            has_errors=True,
        )

    monkeypatch.setattr(
        notifications_api.NotificationService,
        "send_test_delivery",
        fake_send_test_delivery,
    )

    response = client.post(
        "/api/v1/notifications/test-delivery",
        headers=auth_headers,
        json={
            "title": "Test delivery",
            "body": "Messaggio di test",
            "notification_type": NotificationType.REPORT_READY.value,
            "priority": NotificationPriority.NORMAL.value,
            "include_push": True,
            "include_email": True,
            "email_address": "patient@example.com",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["push"]["provider"] == "webhook"
    assert body["email"]["provider"] == "smtp"
    assert body["has_errors"] is True
    assert captured["payload"].title == "Test delivery"
    assert captured["payload"].include_push is True
    assert captured["user_email"] == "patient@example.com"
