from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from dataclasses import asdict
from uuid import uuid4
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.enums import (
    AlertStatus,
    DocumentContextStatus,
    DocumentParsedStatus,
    NotificationPriority,
    NotificationType,
    ScreeningStatus,
)
from app.models.notification import Notification
from app.models.notification_device_token import NotificationDeviceToken
from app.models.notification_preference import NotificationPreference
from app.models.screening_notification import ScreeningNotification
from app.models.user import User
from app.repositories.alert_repository import AlertRepository
from app.repositories.daily_entry_repository import DailyEntryRepository
from app.repositories.document_repository import DocumentRepository
from app.repositories.notification_device_repository import NotificationDeviceRepository
from app.repositories.notification_preference_repository import NotificationPreferenceRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.profile_repository import ProfileRepository
from app.repositories.report_repository import ReportRepository
from app.repositories.screening_repository import ScreeningRepository
from app.schemas.notifications import (
    NotificationDeviceRegistrationRequest,
    NotificationDeliveryReportResponse,
    NotificationTestDeliveryRequest,
    NotificationPreferencesUpdateRequest,
)
from app.services.audit_service import AuditService
from app.services.profile_context import resolve_user_profile
from app.services.notification_delivery_service import NotificationDeliveryService


class NotificationService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.notification_repository = NotificationRepository(db)
        self.notification_device_repository = NotificationDeviceRepository(db)
        self.notification_preference_repository = NotificationPreferenceRepository(db)
        self.daily_entry_repository = DailyEntryRepository(db)
        self.alert_repository = AlertRepository(db)
        self.document_repository = DocumentRepository(db)
        self.profile_repository = ProfileRepository(db)
        self.report_repository = ReportRepository(db)
        self.screening_repository = ScreeningRepository(db)
        self.delivery_service = NotificationDeliveryService()
        self.audit_service = AuditService(db)

    def list_notifications(self, user: User):
        profile_ids = self._profile_ids_for_user(user)
        for patient_id in profile_ids:
            self.sync_patient_notifications(patient_id)
        return self.notification_repository.list_active_for_patients(profile_ids)

    def get_preferences(self, user: User) -> NotificationPreference:
        profile = self._require_profile(user)
        preferences = self._get_or_create_preferences(profile.id)
        self.db.commit()
        self.db.refresh(preferences)
        return preferences

    def update_preferences(
        self,
        user: User,
        payload: NotificationPreferencesUpdateRequest,
    ) -> NotificationPreference:
        profile = self._require_profile(user)
        preferences = self._get_or_create_preferences(profile.id)
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(preferences, field, value)
        self.sync_patient_notifications(profile.id)
        self.audit_service.log_for_user(
            user,
            event_type="notification_preferences_updated",
            entity_type="notification_preferences",
            entity_id=preferences.id,
            summary="Preferenze notifiche aggiornate.",
            metadata=payload.model_dump(exclude_unset=True),
        )
        self.db.commit()
        self.db.refresh(preferences)
        return preferences

    def mark_read(self, user: User, notification_id: UUID):
        profile_ids = self._profile_ids_for_user(user)
        notification = self.notification_repository.get_for_patients(
            profile_ids,
            notification_id,
        )
        if notification is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
        notification.read_status = True
        notification.read_at = utcnow()
        self.audit_service.log_for_user(
            user,
            event_type="notification_marked_read",
            entity_type="notification",
            entity_id=notification.id,
            summary=f"Notifica letta: {notification.title}",
        )
        self.db.commit()
        self.db.refresh(notification)
        return notification

    def sync_patient_notifications(self, patient_id: UUID) -> None:
        preferences = self._get_or_create_preferences(patient_id)
        if not self._has_any_delivery_channel(preferences):
            for item in self.notification_repository.list_active_for_patient(patient_id):
                item.is_active = False
            self.db.commit()
            return

        self._sync_dynamic_notifications(patient_id, preferences=preferences)
        self.db.commit()

    def sync_all_patients(self) -> int:
        synced = 0
        for patient_id in self.profile_repository.list_patient_ids():
            self.sync_patient_notifications(patient_id)
            synced += 1
        return synced

    def sync_screening_notifications_for_patient(self, patient_id: UUID) -> None:
        profile = self._require_profile_by_id(patient_id)
        region_code = self._region_code_string(profile.region_code) or "IT"
        preferences = self._get_or_create_preferences(patient_id)
        statuses = self.screening_repository.list_statuses_for_patient(patient_id)
        active_due_ids = {
            item.id for item in statuses if item.status in {ScreeningStatus.RECOMMENDED, ScreeningStatus.OVERDUE}
        }
        for item in statuses:
            reminder_key = f"screening-reminder-{item.id}"
            prevention_key = f"prevention-tip-{item.id}"
            should_emit_reminder = (
                item.status == ScreeningStatus.OVERDUE or item.screening_program.public_coverage_flag
            )
            if item.status in {ScreeningStatus.RECOMMENDED, ScreeningStatus.OVERDUE}:
                reminder = None
                if should_emit_reminder:
                    reminder = self._upsert_notification(
                        patient_id=patient_id,
                        dedupe_key=reminder_key,
                        notification_type=NotificationType.SCREENING_REMINDER,
                        title=f"Screening da programmare: {item.screening_program.name}",
                        body=item.recommendation_reason
                        or "Lo screening risulta consigliato o scaduto in base al profilo clinico.",
                        priority=NotificationPriority.HIGH
                        if item.status == ScreeningStatus.OVERDUE
                        else NotificationPriority.NORMAL,
                        source_type="patient_screening_status",
                        source_id=item.id,
                        is_active=True,
                        preferences=preferences,
                    )
                else:
                    self._deactivate_by_dedupe(patient_id, reminder_key)
                screening_notification = self.screening_repository.get_screening_notification(patient_id, item.id)
                if reminder is None:
                    if screening_notification is not None:
                        screening_notification.active = False
                elif screening_notification is None:
                    self.screening_repository.add_screening_notification(
                        ScreeningNotification(
                            patient_id=patient_id,
                            screening_program_id=item.screening_program_id,
                            patient_screening_status_id=item.id,
                            notification_id=reminder.id,
                            scheduled_for=self._screening_due_datetime(item.next_due_date),
                            sent_at=utcnow(),
                            active=True,
                        )
                    )
                else:
                    screening_notification.notification_id = reminder.id
                    screening_notification.scheduled_for = self._screening_due_datetime(item.next_due_date)
                    screening_notification.sent_at = utcnow()
                    screening_notification.active = True

                if item.screening_program.public_coverage_flag:
                    availability = self._availability_for_region(
                        item.screening_program.regional_availability,
                        region_code,
                    )
                    self._upsert_notification(
                        patient_id=patient_id,
                        dedupe_key=prevention_key,
                        notification_type=NotificationType.PREVENTION_TIP,
                        title=f"Prevenzione disponibile: {item.screening_program.name}",
                        body=(
                            f"Screening con copertura pubblica disponibile in {availability.region_name}. "
                            f"Consulta {availability.booking_url or 'la tua ASL'} per i dettagli."
                        )
                        if availability is not None
                        else "Programma pubblico disponibile: verifica la tua ASL di riferimento.",
                        priority=NotificationPriority.LOW,
                        source_type="patient_screening_status",
                        source_id=item.id,
                        is_active=True,
                        preferences=preferences,
                    )
            else:
                self._deactivate_by_dedupe(patient_id, reminder_key)
                self._deactivate_by_dedupe(patient_id, prevention_key)
                screening_notification = self.screening_repository.get_screening_notification(patient_id, item.id)
                if screening_notification is not None:
                    screening_notification.active = False

        for screening_notification in self.screening_repository.list_screening_notifications(patient_id):
            if screening_notification.patient_screening_status_id not in active_due_ids:
                screening_notification.active = False

    def sync_medication_notifications_for_patient(self, patient_id: UUID) -> None:
        # Medication reminders are device-local by design. The backend keeps
        # preferences and schedules, but must not generate in-app/push/email
        # medication reminders to avoid duplicates with the local scheduler.
        self._deactivate_notifications_by_type(
            patient_id,
            NotificationType.MEDICATION_REMINDER,
        )

    def _sync_dynamic_notifications(
        self,
        patient_id: UUID,
        *,
        preferences: NotificationPreference | None = None,
    ) -> None:
        from app.services.screening_service import ScreeningService

        preferences = preferences or self._get_or_create_preferences(patient_id)
        ScreeningService(self.db)._recompute_for_profile(patient_id, emit_notifications=False)
        self.sync_screening_notifications_for_patient(patient_id)
        self.sync_medication_notifications_for_patient(patient_id)
        self._sync_daily_checkin_notification(patient_id, preferences)
        self._sync_alert_notifications(patient_id, preferences)
        self._sync_document_notifications(patient_id, preferences)
        self._sync_report_notifications(patient_id, preferences)

    def _sync_daily_checkin_notification(
        self,
        patient_id: UUID,
        preferences: NotificationPreference,
    ) -> None:
        dedupe_key = f"daily-checkin-{date.today().isoformat()}"
        entry = self.daily_entry_repository.get_by_date(patient_id, date.today())
        if entry is None:
            self._upsert_notification(
                patient_id=patient_id,
                dedupe_key=dedupe_key,
                notification_type=NotificationType.DAILY_CHECKIN_REMINDER,
                title="Reminder diario clinico",
                body="Manca il check-up di oggi. Puoi aggiornarlo in meno di un minuto.",
                priority=NotificationPriority.NORMAL,
                source_type="daily_entry",
                source_id=None,
                is_active=True,
                preferences=preferences,
            )
            return
        self._deactivate_by_dedupe(patient_id, dedupe_key)

    def _sync_alert_notifications(
        self,
        patient_id: UUID,
        preferences: NotificationPreference,
    ) -> None:
        open_alerts = self.alert_repository.list_for_patient(patient_id, status=AlertStatus.OPEN)
        open_ids = {alert.id for alert in open_alerts}
        for alert in open_alerts:
            self._upsert_notification(
                patient_id=patient_id,
                dedupe_key=f"alert-{alert.id}",
                notification_type=NotificationType.CLINICAL_ALERT,
                title=alert.title,
                body=alert.description,
                priority=NotificationPriority.URGENT
                if alert.severity.value == "urgency"
                else NotificationPriority.HIGH,
                source_type="alert",
                source_id=alert.id,
                is_active=True,
                preferences=preferences,
            )

        for item in self.notification_repository.list_active_for_patient(patient_id):
            if item.notification_type == NotificationType.CLINICAL_ALERT and item.source_id not in open_ids:
                item.is_active = False

    def _sync_document_notifications(
        self,
        patient_id: UUID,
        preferences: NotificationPreference,
    ) -> None:
        actionable_statuses = {
            DocumentParsedStatus.PENDING,
            DocumentParsedStatus.OCR_PENDING,
            DocumentParsedStatus.REVIEW_REQUIRED,
            DocumentParsedStatus.FAILED,
        }
        documents = self.document_repository.list_for_patient(
            patient_id,
            context_status=DocumentContextStatus.ACTIVE,
        )
        current_ids = set()
        for document in documents:
            dedupe_key = f"document-follow-up-{document.id}"
            if document.parsed_status in actionable_statuses:
                current_ids.add(document.id)
                body = document.processing_error or "Documento ancora da completare o rivedere."
                self._upsert_notification(
                    patient_id=patient_id,
                    dedupe_key=dedupe_key,
                    notification_type=NotificationType.DOCUMENT_FOLLOW_UP,
                    title=f"Documento da completare: {document.title}",
                    body=body,
                    priority=NotificationPriority.NORMAL,
                    source_type="clinical_document",
                    source_id=document.id,
                    is_active=True,
                    preferences=preferences,
                )
            else:
                self._deactivate_by_dedupe(patient_id, dedupe_key)

        for item in self.notification_repository.list_active_for_patient(patient_id):
            if item.notification_type == NotificationType.DOCUMENT_FOLLOW_UP and item.source_id not in current_ids:
                item.is_active = False

    def _sync_report_notifications(
        self,
        patient_id: UUID,
        preferences: NotificationPreference,
    ) -> None:
        threshold = utcnow() - timedelta(days=14)
        for report in self.report_repository.list_recent_for_patient(patient_id, limit=5):
            generated_at = report.generated_at
            if generated_at.tzinfo is None:
                generated_at = generated_at.replace(tzinfo=threshold.tzinfo)
            if generated_at < threshold:
                continue
            self._upsert_notification(
                patient_id=patient_id,
                dedupe_key=f"report-ready-{report.id}",
                notification_type=NotificationType.REPORT_READY,
                title=f"Report pronto: {report.title}",
                body="Il report PDF e disponibile per consultazione o condivisione.",
                priority=NotificationPriority.LOW,
                source_type="report",
                source_id=report.id,
                is_active=True,
                preferences=preferences,
            )

    def _upsert_notification(
        self,
        *,
        patient_id: UUID,
        dedupe_key: str,
        notification_type: NotificationType,
        title: str,
        body: str,
        priority: NotificationPriority,
        source_type: str | None,
        source_id: UUID | None,
        is_active: bool,
        preferences: NotificationPreference,
    ) -> Notification | None:
        if not self._is_notification_enabled(preferences, notification_type):
            self._deactivate_by_dedupe(patient_id, dedupe_key)
            return None

        notification = self.notification_repository.get_by_dedupe(patient_id, dedupe_key)
        should_dispatch = False
        if notification is None:
            notification = Notification(
                patient_id=patient_id,
                notification_type=notification_type,
                title=title,
                body=body,
                priority=priority,
                source_type=source_type,
                source_id=source_id,
                dedupe_key=dedupe_key,
                is_active=is_active,
            )
            self.notification_repository.add(notification)
            self.db.flush()
            should_dispatch = is_active
        else:
            should_dispatch = (
                is_active
                and (
                    not notification.is_active
                    or notification.title != title
                    or notification.body != body
                    or notification.priority != priority
                )
            )

            notification.notification_type = notification_type
            notification.title = title
            notification.body = body
            notification.priority = priority
            notification.source_type = source_type
            notification.source_id = source_id
            notification.is_active = is_active

        if should_dispatch:
            self._dispatch_external_channels(patient_id=patient_id, notification=notification, preferences=preferences)
        return notification

    def register_device(
        self,
        user: User,
        payload: NotificationDeviceRegistrationRequest,
    ) -> NotificationDeviceToken:
        profile = self._require_profile(user)
        token = self.notification_device_repository.get_by_token(profile.id, payload.device_token)
        if token is None:
            token = NotificationDeviceToken(
                patient_id=profile.id,
                platform=payload.platform.strip().lower(),
                device_token=payload.device_token.strip(),
                device_label=payload.device_label,
                active=True,
                last_seen_at=utcnow(),
            )
            self.notification_device_repository.add(token)
        else:
            token.platform = payload.platform.strip().lower()
            token.device_label = payload.device_label
            token.active = True
            token.last_seen_at = utcnow()
        self.audit_service.log_for_user(
            user,
            event_type="notification_device_registered",
            entity_type="notification_device_token",
            entity_id=token.id,
            summary=f"Device notifiche registrato: {token.platform}",
            metadata={"device_label": token.device_label},
        )
        self.db.commit()
        self.db.refresh(token)
        return token

    def send_test_delivery(
        self,
        user: User,
        payload: NotificationTestDeliveryRequest,
    ) -> NotificationDeliveryReportResponse:
        profile = self._require_profile(user)
        preferences = self._get_or_create_preferences(profile.id)
        device_tokens = self.notification_device_repository.list_for_patient(profile.id)
        notification = Notification(
            patient_id=profile.id,
            notification_type=payload.notification_type,
            title=payload.title,
            body=payload.body,
            priority=payload.priority,
            dedupe_key=f"notification-test-{uuid4()}",
            is_active=True,
        )
        test_preferences = NotificationPreference(
            patient_id=profile.id,
            in_app_enabled=True,
            daily_checkin_enabled=preferences.daily_checkin_enabled,
            medication_reminders_enabled=preferences.medication_reminders_enabled,
            screening_reminders_enabled=preferences.screening_reminders_enabled,
            document_follow_up_enabled=preferences.document_follow_up_enabled,
            report_ready_enabled=preferences.report_ready_enabled,
            clinical_alerts_enabled=preferences.clinical_alerts_enabled,
            prevention_tips_enabled=preferences.prevention_tips_enabled,
            push_enabled=payload.include_push,
            email_enabled=payload.include_email,
            email_address=payload.email_address or preferences.email_address,
        )
        report = self.delivery_service.dispatch(
            notification=notification,
            preferences=test_preferences,
            device_tokens=device_tokens,
        )
        self.audit_service.log_for_user(
            user,
            event_type="notification_delivery_test",
            entity_type="notification_delivery",
            entity_id=profile.id,
            summary="Test delivery notifiche eseguito.",
            metadata={
                "include_push": payload.include_push,
                "include_email": payload.include_email,
                "push_provider": report.push.provider if report.push is not None else None,
                "email_provider": report.email.provider if report.email is not None else None,
                "push_delivered": report.push.delivered if report.push is not None else None,
                "email_delivered": report.email.delivered if report.email is not None else None,
            },
        )
        self.db.commit()
        return NotificationDeliveryReportResponse.model_validate(asdict(report))

    def _deactivate_by_dedupe(self, patient_id: UUID, dedupe_key: str) -> None:
        notification = self.notification_repository.get_by_dedupe(patient_id, dedupe_key)
        if notification is not None:
            notification.is_active = False

    def _deactivate_notifications_by_type(
        self,
        patient_id: UUID,
        notification_type: NotificationType,
    ) -> None:
        for notification in self.notification_repository.list_active_for_patient(patient_id):
            if notification.notification_type == notification_type:
                notification.is_active = False

    def _get_or_create_preferences(self, patient_id: UUID) -> NotificationPreference:
        preferences = self.notification_preference_repository.get_for_patient(patient_id)
        if preferences is not None:
            return preferences

        preferences = NotificationPreference(patient_id=patient_id)
        self.notification_preference_repository.add(preferences)
        self.db.flush()
        return preferences

    @staticmethod
    def _is_notification_enabled(
        preferences: NotificationPreference,
        notification_type: NotificationType,
    ) -> bool:
        flag_by_type = {
            NotificationType.DAILY_CHECKIN_REMINDER: preferences.daily_checkin_enabled,
            NotificationType.MEDICATION_REMINDER: preferences.medication_reminders_enabled,
            NotificationType.SCREENING_REMINDER: preferences.screening_reminders_enabled,
            NotificationType.DOCUMENT_FOLLOW_UP: preferences.document_follow_up_enabled,
            NotificationType.REPORT_READY: preferences.report_ready_enabled,
            NotificationType.CLINICAL_ALERT: preferences.clinical_alerts_enabled,
            NotificationType.PREVENTION_TIP: preferences.prevention_tips_enabled,
        }
        return flag_by_type[notification_type]

    def _dispatch_external_channels(
        self,
        *,
        patient_id: UUID,
        notification: Notification,
        preferences: NotificationPreference,
    ) -> None:
        if not (preferences.push_enabled or preferences.email_enabled):
            return
        device_tokens = self.notification_device_repository.list_for_patient(patient_id)
        self.delivery_service.dispatch(
            notification=notification,
            preferences=preferences,
            device_tokens=device_tokens,
        )

    @staticmethod
    def _has_any_delivery_channel(preferences: NotificationPreference) -> bool:
        return preferences.in_app_enabled or preferences.push_enabled or preferences.email_enabled

    @staticmethod
    def _screening_due_datetime(due_date: date | None) -> datetime | None:
        if due_date is None:
            return None
        return datetime.combine(due_date, time(hour=9), tzinfo=timezone.utc)

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    def _profile_ids_for_user(self, user: User) -> list[UUID]:
        profiles = self.profile_repository.list_profiles_by_user_id(user.id)
        if profiles:
            return [profile.id for profile in profiles]
        profile = self._require_profile(user)
        return [profile.id]

    def _require_profile_by_id(self, patient_id: UUID):
        from app.models.patient_profile import PatientProfile

        profile = self.db.get(PatientProfile, patient_id)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    @staticmethod
    def _availability_for_region(availability_items, region_code: str | None):
        normalized_code = region_code.strip().upper() if region_code else None
        filtered = [
            item
            for item in availability_items
            if item.active and (normalized_code is None or item.region_code.upper() == normalized_code)
        ]
        if not filtered:
            filtered = [item for item in availability_items if item.active and item.region_code.upper() == "IT"]
        if not filtered:
            filtered = [item for item in availability_items if item.active]
        return filtered[0] if filtered else None

    @staticmethod
    def _region_code_string(region_code) -> str | None:
        if region_code is None:
            return None
        value = getattr(region_code, "value", region_code)
        return str(value).upper()
