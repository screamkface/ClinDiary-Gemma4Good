from __future__ import annotations

from app.core.config import Settings
import app.notification_delivery_audit as notification_delivery_audit
from app.notification_delivery_audit import audit_notification_delivery_config, main


def test_audit_notification_delivery_config_reports_missing_fields() -> None:
    settings = Settings(
        notification_push_provider="fcm",
        notification_fcm_project_id="demo-project",
        notification_email_provider="smtp",
        smtp_host=None,
    )

    report = audit_notification_delivery_config(settings)

    assert report.ready is False
    assert report.push.ready is False
    assert report.push.provider == "fcm"
    assert any(
        field.startswith("notification_fcm_access_token")
        or field.startswith("notification_fcm_service_account_json")
        or field.startswith("notification_fcm_service_account_file")
        for field in report.push.missing_fields
    )
    assert report.email.ready is False
    assert report.email.provider == "smtp"
    assert "smtp_host" in report.email.missing_fields


def test_audit_notification_delivery_config_accepts_valid_external_providers() -> None:
    settings = Settings(
        notification_push_provider="webhook",
        notification_push_webhook_url="https://example.org/hooks/push",
        notification_email_provider="smtp",
        smtp_host="smtp.example.org",
    )

    report = audit_notification_delivery_config(settings)

    assert report.ready is True
    assert report.external_ready is True
    assert report.push.ready is True
    assert report.email.ready is True


def test_notification_delivery_audit_main_requires_external_provider(monkeypatch, capsys) -> None:
    monkeypatch.setattr(
        notification_delivery_audit,
        "get_settings",
        lambda: Settings(notification_push_provider="log_only", notification_email_provider="log_only"),
    )

    exit_code = main(["--require-external-provider"])

    output = capsys.readouterr().out
    assert exit_code == 4
    assert "delivery_config_ready=true" in output
    assert "external_provider_required=true" in output
