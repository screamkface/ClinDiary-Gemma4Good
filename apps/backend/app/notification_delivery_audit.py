from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from app.core.config import Settings, get_settings


@dataclass(slots=True)
class NotificationChannelAuditResult:
    channel: str
    provider: str
    ready: bool
    external: bool
    missing_fields: tuple[str, ...] = ()
    notes: tuple[str, ...] = ()


@dataclass(slots=True)
class NotificationDeliveryAuditReport:
    push: NotificationChannelAuditResult
    email: NotificationChannelAuditResult

    @property
    def ready(self) -> bool:
        return self.push.ready and self.email.ready

    @property
    def external_ready(self) -> bool:
        return any(result.external and result.ready for result in (self.push, self.email))


def audit_notification_delivery_config(
    settings: Settings | None = None,
) -> NotificationDeliveryAuditReport:
    resolved = settings or get_settings()
    return NotificationDeliveryAuditReport(
        push=_audit_push(resolved),
        email=_audit_email(resolved),
    )


def _audit_push(settings: Settings) -> NotificationChannelAuditResult:
    provider = _provider_name(settings.notification_push_provider)
    if provider == "log_only":
        return NotificationChannelAuditResult(
            channel="push",
            provider=provider,
            ready=True,
            external=False,
            notes=("modalita di sola simulazione",),
        )

    if provider == "webhook":
        missing: list[str] = []
        webhook_url = _clean_text(settings.notification_push_webhook_url)
        if webhook_url is None:
            missing.append("notification_push_webhook_url")
        elif not _looks_like_http_url(webhook_url):
            missing.append("notification_push_webhook_url (URL non valido)")
        return NotificationChannelAuditResult(
            channel="push",
            provider=provider,
            ready=not missing,
            external=True,
            missing_fields=tuple(missing),
        )

    if provider == "fcm":
        missing: list[str] = []
        if not _clean_text(settings.notification_fcm_project_id):
            missing.append("notification_fcm_project_id")

        auth_source, auth_missing = _audit_fcm_auth(settings)
        missing.extend(auth_missing)
        notes = (f"auth_source={auth_source}",) if auth_source is not None else ()
        return NotificationChannelAuditResult(
            channel="push",
            provider=provider,
            ready=not missing,
            external=True,
            missing_fields=tuple(missing),
            notes=notes,
        )

    if provider == "apns":
        missing = []
        if not _clean_text(settings.notification_apns_key_id):
            missing.append("notification_apns_key_id")
        if not _clean_text(settings.notification_apns_team_id):
            missing.append("notification_apns_team_id")
        if not _clean_text(settings.notification_apns_bundle_id):
            missing.append("notification_apns_bundle_id")
        if not _clean_text(settings.notification_apns_private_key):
            missing.append("notification_apns_private_key")
        return NotificationChannelAuditResult(
            channel="push",
            provider=provider,
            ready=not missing,
            external=True,
            missing_fields=tuple(missing),
            notes=(f"sandbox={str(settings.notification_apns_use_sandbox).lower()}",),
        )

    return NotificationChannelAuditResult(
        channel="push",
        provider=provider,
        ready=False,
        external=True,
        missing_fields=(f"notification_push_provider non supportato: {provider}",),
    )


def _audit_email(settings: Settings) -> NotificationChannelAuditResult:
    provider = _provider_name(settings.notification_email_provider)
    if provider == "log_only":
        return NotificationChannelAuditResult(
            channel="email",
            provider=provider,
            ready=True,
            external=False,
            notes=("modalita di sola simulazione",),
        )

    if provider == "smtp":
        missing = []
        if not _clean_text(settings.smtp_host):
            missing.append("smtp_host")
        if not _clean_text(settings.notification_email_from):
            missing.append("notification_email_from")
        if settings.smtp_port <= 0 or settings.smtp_port > 65535:
            missing.append("smtp_port")
        notes = (f"tls={str(settings.smtp_use_tls).lower()}",)
        return NotificationChannelAuditResult(
            channel="email",
            provider=provider,
            ready=not missing,
            external=True,
            missing_fields=tuple(missing),
            notes=notes,
        )

    return NotificationChannelAuditResult(
        channel="email",
        provider=provider,
        ready=False,
        external=True,
        missing_fields=(f"notification_email_provider non supportato: {provider}",),
    )


def _audit_fcm_auth(settings: Settings) -> tuple[str | None, tuple[str, ...]]:
    access_token = _clean_text(settings.notification_fcm_access_token)
    if access_token is not None:
        return "access_token", ()

    service_account_json = _clean_text(settings.notification_fcm_service_account_json)
    if service_account_json is not None:
        try:
            parsed = json.loads(service_account_json)
            if not isinstance(parsed, dict):
                return None, ("notification_fcm_service_account_json (deve essere un oggetto JSON)",)
            return "service_account_json", ()
        except Exception:
            return None, ("notification_fcm_service_account_json (JSON non valido)",)

    service_account_file = _clean_text(settings.notification_fcm_service_account_file)
    if service_account_file is not None:
        path = Path(service_account_file).expanduser()
        if not path.exists():
            return None, ("notification_fcm_service_account_file (file non trovato)",)
        try:
            parsed = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(parsed, dict):
                return None, ("notification_fcm_service_account_file (deve contenere un oggetto JSON)",)
            return "service_account_file", ()
        except Exception:
            return None, ("notification_fcm_service_account_file (JSON non valido)",)

    return None, (
        "notification_fcm_access_token / notification_fcm_service_account_json / notification_fcm_service_account_file",
    )


def _clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _provider_name(value: str | None) -> str:
    return (_clean_text(value) or "log_only").lower()


def _looks_like_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def _print_result(report: NotificationDeliveryAuditReport) -> None:
    for result in (report.push, report.email):
        print(f"{result.channel}_provider={result.provider}")
        print(f"{result.channel}_ready={str(result.ready).lower()}")
        print(f"{result.channel}_external={str(result.external).lower()}")
        if result.missing_fields:
            print(f"{result.channel}_missing={', '.join(result.missing_fields)}")
        if result.notes:
            print(f"{result.channel}_notes={', '.join(result.notes)}")
    print(f"delivery_config_ready={str(report.ready).lower()}")
    print(f"delivery_provider_ready={str(report.external_ready).lower()}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ClinDiary notification delivery config audit")
    parser.add_argument(
        "--require-delivery-provider",
        action="store_true",
        help="Fallisce se push/email restano in log_only o se nessun canale reale e pronto.",
    )
    args = parser.parse_args(argv)

    report = audit_notification_delivery_config(get_settings())
    _print_result(report)

    if args.require_delivery_provider and not report.external_ready:
        print("delivery_provider_required=true")
        return 4 if report.ready else 1

    return 0 if report.ready else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
