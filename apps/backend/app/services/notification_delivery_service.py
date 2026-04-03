from __future__ import annotations

from dataclasses import dataclass
from email.message import EmailMessage
import json
import smtplib
import time

import httpx
import jwt

from app.core.config import Settings, get_settings
from app.core.logging import logger
from app.models.notification import Notification
from app.models.notification_device_token import NotificationDeviceToken
from app.models.notification_preference import NotificationPreference


@dataclass(slots=True)
class NotificationChannelDeliveryResult:
    channel: str
    provider: str
    attempted: bool
    delivered: bool
    target_count: int = 0
    delivered_count: int = 0
    error: str | None = None


@dataclass(slots=True)
class NotificationDeliveryReport:
    push: NotificationChannelDeliveryResult | None = None
    email: NotificationChannelDeliveryResult | None = None

    @property
    def attempted(self) -> bool:
        return any(result.attempted for result in (self.push, self.email) if result is not None)

    @property
    def delivered(self) -> bool:
        return any(result.delivered for result in (self.push, self.email) if result is not None)

    @property
    def has_errors(self) -> bool:
        return any(result.error for result in (self.push, self.email) if result is not None)


class NotificationDeliveryService:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    def dispatch(
        self,
        *,
        notification: Notification,
        preferences: NotificationPreference,
        device_tokens: list[NotificationDeviceToken],
    ) -> NotificationDeliveryReport:
        report = NotificationDeliveryReport()
        if preferences.push_enabled:
            if device_tokens:
                report.push = self._dispatch_push(notification=notification, device_tokens=device_tokens)
            else:
                report.push = NotificationChannelDeliveryResult(
                    channel="push",
                    provider=(self.settings.notification_push_provider or "log_only").strip().lower(),
                    attempted=True,
                    delivered=False,
                    error="Nessun device registrato per il paziente.",
                )

        if preferences.email_enabled:
            if preferences.email_address:
                report.email = self._dispatch_email(
                    notification=notification,
                    email_address=preferences.email_address,
                )
            else:
                report.email = NotificationChannelDeliveryResult(
                    channel="email",
                    provider=(self.settings.notification_email_provider or "log_only").strip().lower(),
                    attempted=True,
                    delivered=False,
                    error="Indirizzo email mancante.",
                )
        return report

    def _dispatch_push(
        self,
        *,
        notification: Notification,
        device_tokens: list[NotificationDeviceToken],
    ) -> NotificationChannelDeliveryResult:
        payload = {
            "notification_id": str(notification.id),
            "type": notification.notification_type.value,
            "title": notification.title,
            "body": notification.body,
            "priority": notification.priority.value,
            "devices": [
                {
                    "platform": item.platform,
                    "device_token": item.device_token,
                    "device_label": item.device_label,
                }
                for item in device_tokens
            ],
        }

        provider = (self.settings.notification_push_provider or "log_only").strip().lower()

        if provider == "webhook":
            if not self.settings.notification_push_webhook_url:
                error = "Webhook push non configurato: notification_push_webhook_url mancante."
                logger.warning(
                    "notifications.push_failed",
                    provider="webhook",
                    notification_id=str(notification.id),
                    error=error,
                )
                return NotificationChannelDeliveryResult(
                    channel="push",
                    provider="webhook",
                    attempted=True,
                    delivered=False,
                    target_count=len(device_tokens),
                    error=error,
                )
            try:
                response = httpx.post(
                    self.settings.notification_push_webhook_url,
                    json=payload,
                    timeout=10,
                )
                response.raise_for_status()
                logger.info(
                    "notifications.push_dispatched",
                    provider="webhook",
                    notification_id=str(notification.id),
                    device_count=len(device_tokens),
                )
                return NotificationChannelDeliveryResult(
                    channel="push",
                    provider="webhook",
                    attempted=True,
                    delivered=True,
                    target_count=len(device_tokens),
                    delivered_count=len(device_tokens),
                )
            except Exception as exc:
                logger.warning(
                    "notifications.push_failed",
                    provider="webhook",
                    notification_id=str(notification.id),
                    error=str(exc),
                )
                return NotificationChannelDeliveryResult(
                    channel="push",
                    provider="webhook",
                    attempted=True,
                    delivered=False,
                    target_count=len(device_tokens),
                    error=str(exc),
                )

        if provider == "fcm":
            return self._dispatch_push_fcm(notification=notification, device_tokens=device_tokens)

        if provider == "apns":
            return self._dispatch_push_apns(notification=notification, device_tokens=device_tokens)

        if provider != "log_only":
            error = f"Provider push non supportato: {provider}"
            logger.warning(
                "notifications.push_failed",
                provider=provider,
                notification_id=str(notification.id),
                error=error,
            )
            return NotificationChannelDeliveryResult(
                channel="push",
                provider=provider,
                attempted=True,
                delivered=False,
                target_count=len(device_tokens),
                error=error,
            )

        logger.info(
            "notifications.push_logged",
            provider=provider,
            notification_id=str(notification.id),
            device_count=len(device_tokens),
        )
        return NotificationChannelDeliveryResult(
            channel="push",
            provider=provider,
            attempted=True,
            delivered=False,
            target_count=len(device_tokens),
        )

    def _dispatch_email(
        self,
        *,
        notification: Notification,
        email_address: str,
    ) -> NotificationChannelDeliveryResult:
        provider = (self.settings.notification_email_provider or "log_only").strip().lower()
        if provider == "smtp":
            if not self.settings.smtp_host:
                error = "SMTP non configurato: host mancante."
                logger.warning(
                    "notifications.email_failed",
                    provider="smtp",
                    notification_id=str(notification.id),
                    email_address=email_address,
                    error=error,
                )
                return NotificationChannelDeliveryResult(
                    channel="email",
                    provider="smtp",
                    attempted=True,
                    delivered=False,
                    target_count=1,
                    error=error,
                )
            message = EmailMessage()
            message["Subject"] = self._email_subject(notification)
            message["From"] = self.settings.notification_email_from
            message["To"] = email_address
            message.set_content(self._email_text_body(notification))
            message.add_alternative(self._email_html_body(notification), subtype="html")
            try:
                with smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port, timeout=10) as smtp:
                    if self.settings.smtp_use_tls:
                        smtp.starttls()
                    if self.settings.smtp_username and self.settings.smtp_password:
                        smtp.login(self.settings.smtp_username, self.settings.smtp_password)
                    smtp.send_message(message)
                logger.info(
                    "notifications.email_dispatched",
                    provider="smtp",
                    notification_id=str(notification.id),
                    email_address=email_address,
                )
                return NotificationChannelDeliveryResult(
                    channel="email",
                    provider="smtp",
                    attempted=True,
                    delivered=True,
                    target_count=1,
                    delivered_count=1,
                )
            except Exception as exc:
                logger.warning(
                    "notifications.email_failed",
                    provider="smtp",
                    notification_id=str(notification.id),
                    email_address=email_address,
                    error=str(exc),
                )
                return NotificationChannelDeliveryResult(
                    channel="email",
                    provider="smtp",
                    attempted=True,
                    delivered=False,
                    target_count=1,
                    error=str(exc),
                )

        if provider != "log_only":
            error = f"Provider email non supportato: {provider}"
            logger.warning(
                "notifications.email_failed",
                provider=provider,
                notification_id=str(notification.id),
                email_address=email_address,
                error=error,
            )
            return NotificationChannelDeliveryResult(
                channel="email",
                provider=provider,
                attempted=True,
                delivered=False,
                target_count=1,
                error=error,
            )

        logger.info(
            "notifications.email_logged",
            provider=provider,
            notification_id=str(notification.id),
            email_address=email_address,
        )
        return NotificationChannelDeliveryResult(
            channel="email",
            provider=provider,
            attempted=True,
            delivered=False,
            target_count=1,
        )

    def _dispatch_push_fcm(
        self,
        *,
        notification: Notification,
        device_tokens: list[NotificationDeviceToken],
    ) -> NotificationChannelDeliveryResult:
        project_id = self.settings.notification_fcm_project_id
        access_token = self._resolve_fcm_access_token()
        if not project_id or not access_token:
            error = "FCM non configurato: project_id o access_token mancanti."
            logger.warning(
                "notifications.push_failed",
                provider="fcm",
                notification_id=str(notification.id),
                error=error,
            )
            return NotificationChannelDeliveryResult(
                channel="push",
                provider="fcm",
                attempted=True,
                delivered=False,
                target_count=len(device_tokens),
                error=error,
            )

        success_count = 0
        for item in device_tokens:
            try:
                response = httpx.post(
                    f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send",
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "message": {
                            "token": item.device_token,
                            "notification": {
                                "title": notification.title,
                                "body": notification.body,
                            },
                            "data": {
                                "notification_id": str(notification.id),
                                "type": notification.notification_type.value,
                                "priority": notification.priority.value,
                            },
                        }
                    },
                    timeout=10,
                )
                response.raise_for_status()
                success_count += 1
            except Exception as exc:
                logger.warning(
                    "notifications.push_failed",
                    provider="fcm",
                    notification_id=str(notification.id),
                    device_token=item.device_token[:16],
                    error=str(exc),
                )

        if success_count == len(device_tokens):
            logger.info(
                "notifications.push_dispatched",
                provider="fcm",
                notification_id=str(notification.id),
                device_count=success_count,
            )
            return NotificationChannelDeliveryResult(
                channel="push",
                provider="fcm",
                attempted=True,
                delivered=True,
                target_count=len(device_tokens),
                delivered_count=success_count,
            )

        error = f"Solo {success_count}/{len(device_tokens)} device hanno ricevuto la notifica via FCM."
        logger.warning(
            "notifications.push_failed",
            provider="fcm",
            notification_id=str(notification.id),
            error=error,
        )
        return NotificationChannelDeliveryResult(
            channel="push",
            provider="fcm",
            attempted=True,
            delivered=success_count > 0,
            target_count=len(device_tokens),
            delivered_count=success_count,
            error=error,
        )

    def _dispatch_push_apns(
        self,
        *,
        notification: Notification,
        device_tokens: list[NotificationDeviceToken],
    ) -> NotificationChannelDeliveryResult:
        apns_token = self._build_apns_token()
        bundle_id = self.settings.notification_apns_bundle_id
        if not apns_token or not bundle_id:
            error = "APNs non configurato: token/bundle id mancanti."
            logger.warning(
                "notifications.push_failed",
                provider="apns",
                notification_id=str(notification.id),
                error=error,
            )
            return NotificationChannelDeliveryResult(
                channel="push",
                provider="apns",
                attempted=True,
                delivered=False,
                target_count=0,
                error=error,
            )

        target_tokens = [
            item for item in device_tokens if item.platform.strip().lower() in {"ios", "iphone", "ipad"}
        ]
        if not target_tokens:
            logger.info(
                "notifications.push_logged",
                provider="apns",
                notification_id=str(notification.id),
                device_count=0,
            )
            return NotificationChannelDeliveryResult(
                channel="push",
                provider="apns",
                attempted=True,
                delivered=False,
                target_count=0,
                error="Nessun device iOS compatibile disponibile.",
            )

        base_url = (
            "https://api.sandbox.push.apple.com"
            if self.settings.notification_apns_use_sandbox
            else "https://api.push.apple.com"
        )
        success_count = 0
        with httpx.Client(http2=True, timeout=10) as client:
            for item in target_tokens:
                try:
                    response = client.post(
                        f"{base_url}/3/device/{item.device_token}",
                        headers={
                            "authorization": f"bearer {apns_token}",
                            "apns-topic": bundle_id,
                            "apns-push-type": "alert",
                        },
                        json={
                            "aps": {
                                "alert": {
                                    "title": notification.title,
                                    "body": notification.body,
                                },
                                "sound": "default",
                            }
                        },
                    )
                    response.raise_for_status()
                    success_count += 1
                except Exception as exc:
                    logger.warning(
                        "notifications.push_failed",
                        provider="apns",
                        notification_id=str(notification.id),
                        device_token=item.device_token[:16],
                        error=str(exc),
                    )

        if success_count == len(target_tokens):
            logger.info(
                "notifications.push_dispatched",
                provider="apns",
                notification_id=str(notification.id),
                device_count=success_count,
            )
            return NotificationChannelDeliveryResult(
                channel="push",
                provider="apns",
                attempted=True,
                delivered=True,
                target_count=len(target_tokens),
                delivered_count=success_count,
            )

        error = f"Solo {success_count}/{len(target_tokens)} device hanno ricevuto la notifica via APNs."
        logger.warning(
            "notifications.push_failed",
            provider="apns",
            notification_id=str(notification.id),
            error=error,
        )
        return NotificationChannelDeliveryResult(
            channel="push",
            provider="apns",
            attempted=True,
            delivered=success_count > 0,
            target_count=len(target_tokens),
            delivered_count=success_count,
            error=error,
        )

    def _resolve_fcm_access_token(self) -> str | None:
        if self.settings.notification_fcm_access_token:
            return self.settings.notification_fcm_access_token

        service_account_json = self.settings.notification_fcm_service_account_json
        service_account_file = self.settings.notification_fcm_service_account_file
        if not service_account_json and not service_account_file:
            return None

        try:
            from google.auth.transport.requests import Request
            from google.oauth2 import service_account

            scopes = ["https://www.googleapis.com/auth/firebase.messaging"]
            if service_account_json:
                info = json.loads(service_account_json)
                credentials = service_account.Credentials.from_service_account_info(
                    info,
                    scopes=scopes,
                )
            else:
                credentials = service_account.Credentials.from_service_account_file(
                    service_account_file,
                    scopes=scopes,
                )
            credentials.refresh(Request())
            return credentials.token
        except Exception as exc:
            logger.warning("notifications.fcm_token_unavailable", error=str(exc))
            return None

    def _build_apns_token(self) -> str | None:
        if not (
            self.settings.notification_apns_key_id
            and self.settings.notification_apns_team_id
            and self.settings.notification_apns_private_key
        ):
            return None

        try:
            issued_at = int(time.time())
            return jwt.encode(
                {"iss": self.settings.notification_apns_team_id, "iat": issued_at},
                self.settings.notification_apns_private_key,
                algorithm="ES256",
                headers={"kid": self.settings.notification_apns_key_id},
            )
        except Exception as exc:
            logger.warning("notifications.apns_token_unavailable", error=str(exc))
            return None

    @staticmethod
    def _email_subject(notification: Notification) -> str:
        return f"ClinDiary: {notification.title}"

    @staticmethod
    def _email_text_body(notification: Notification) -> str:
        return (
            f"{notification.title}\n\n"
            f"{notification.body}\n\n"
            "Questo messaggio ha finalita organizzativa e non sostituisce un parere medico."
        )

    @staticmethod
    def _email_html_body(notification: Notification) -> str:
        return (
            "<html><body style=\"font-family:Arial,sans-serif;line-height:1.5;\">"
            f"<h2>{notification.title}</h2>"
            f"<p>{notification.body}</p>"
            "<p style=\"color:#555;\">Questo messaggio ha finalita organizzativa e non sostituisce un parere medico.</p>"
            "</body></html>"
        )
