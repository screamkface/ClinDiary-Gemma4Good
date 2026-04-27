from __future__ import annotations

import argparse
import json
from pathlib import Path
from uuid import uuid4
import sys

from app.core.config import get_settings
from app.models.base import utcnow
from app.models.enums import NotificationPriority, NotificationType
from app.models.notification import Notification
from app.models.notification_device_token import NotificationDeviceToken
from app.models.notification_preference import NotificationPreference
from app.services.notification_delivery_service import (
    NotificationDeliveryReport,
    NotificationDeliveryService,
)


def _default_payload() -> dict[str, object]:
    return {
        "title": "ClinDiary: notifica di prova",
        "body": "Messaggio di verifica delivery.",
        "notification_type": "report_ready",
        "priority": "normal",
    }


def _load_payload(path: Path | None) -> dict[str, object]:
    if path is None:
        return _default_payload()

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("payload must be a JSON object")
    payload = _default_payload()
    payload.update(data)
    return payload


def _string_value(payload: dict[str, object], key: str, default: str) -> str:
    value = payload.get(key, default)
    if value is None:
        return default
    return str(value)


def _optional_string(payload: dict[str, object], key: str) -> str | None:
    value = payload.get(key)
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _device_tokens(payload: dict[str, object], patient_id) -> list[NotificationDeviceToken]:
    devices = payload.get("devices")
    if devices is None:
        return []
    if not isinstance(devices, list):
        raise ValueError("devices must be a list")

    tokens: list[NotificationDeviceToken] = []
    for item in devices:
        if not isinstance(item, dict):
            raise ValueError("each device must be an object")
        platform = str(item.get("platform", "")).strip()
        device_token = str(item.get("device_token", "")).strip()
        if not platform or not device_token:
            raise ValueError("each device must include platform and device_token")
        device_label = item.get("device_label")
        tokens.append(
            NotificationDeviceToken(
                id=uuid4(),
                patient_id=patient_id,
                platform=platform,
                device_token=device_token,
                device_label=str(device_label).strip() if device_label is not None else None,
                active=True,
                last_seen_at=utcnow(),
            )
        )
    return tokens


def _build_notification(payload: dict[str, object]) -> tuple[Notification, NotificationPreference, list[NotificationDeviceToken]]:
    patient_id = uuid4()
    notification = Notification(
        id=uuid4(),
        patient_id=patient_id,
        notification_type=NotificationType(_string_value(payload, "notification_type", "report_ready")),
        title=_string_value(payload, "title", "ClinDiary: notifica di prova"),
        body=_string_value(payload, "body", "Messaggio di verifica delivery."),
        priority=NotificationPriority(_string_value(payload, "priority", "normal")),
        dedupe_key=f"notification-smoke-{uuid4()}",
        is_active=True,
        created_at=utcnow(),
    )
    email_address = _optional_string(payload, "email_address")
    tokens = _device_tokens(payload, patient_id)
    preferences = NotificationPreference(
        patient_id=patient_id,
        in_app_enabled=True,
        push_enabled=bool(tokens),
        email_enabled=email_address is not None,
        email_address=email_address,
    )
    return notification, preferences, tokens


def _print_result(report: NotificationDeliveryReport) -> None:
    for label, result in ("push", report.push), ("email", report.email):
        requested = result is not None
        print(f"{label}_requested={str(requested).lower()}")
        if not requested:
            continue
        assert result is not None
        print(f"{label}_provider={result.provider}")
        print(f"{label}_attempted={str(result.attempted).lower()}")
        print(f"{label}_delivered={str(result.delivered).lower()}")
        print(f"{label}_target_count={result.target_count}")
        print(f"{label}_delivered_count={result.delivered_count}")
        if result.error:
            print(f"{label}_error={result.error}")
    print(f"delivery_attempted={str(report.attempted).lower()}")
    print(f"delivery_delivered={str(report.delivered).lower()}")
    print(f"delivery_has_errors={str(report.has_errors).lower()}")


def _requires_delivery_provider(report: NotificationDeliveryReport) -> bool:
    requested = False
    for result in (report.push, report.email):
        if result is None:
            continue
        requested = True
        if result.provider == "log_only" or not result.delivered or result.error:
            return False
    return requested


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ClinDiary notification smoke check")
    parser.add_argument(
        "--payload",
        help="Percorso a un JSON con notifica e destinatari da usare per la prova",
        default=None,
    )
    parser.add_argument(
        "--require-delivery-provider",
        action="store_true",
        help="Fallisce se il provider configurato ricade su log_only o se nessun canale reale viene testato",
    )
    args = parser.parse_args(argv)

    payload_path = Path(args.payload) if args.payload else None
    if payload_path is not None and not payload_path.exists():
        print(f"payload_not_found={payload_path}")
        return 2

    try:
        payload = _load_payload(payload_path)
        notification, preferences, device_tokens = _build_notification(payload)
    except Exception as exc:
        print(f"payload_error={exc}")
        return 2

    if not device_tokens and not preferences.email_address:
        print("delivery_skipped=true")
        if args.require_delivery_provider:
            print("delivery_provider_required=true")
            return 4
        return 0

    service = NotificationDeliveryService(get_settings())
    try:
        report = service.dispatch(
            notification=notification,
            preferences=preferences,
            device_tokens=device_tokens,
        )
    except Exception as exc:
        print(f"delivery_error={exc}")
        return 3

    _print_result(report)

    if report.has_errors:
        print("delivery_failed=true")
        return 5

    if args.require_delivery_provider and not _requires_delivery_provider(report):
        print("delivery_provider_required=true")
        return 4

    return 0


if __name__ == "__main__":
    sys.exit(main())
