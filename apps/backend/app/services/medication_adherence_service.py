from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.enums import MedicationLogStatus, TimelineEventType
from app.models.medication_log import MedicationLog
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.repositories.medication_repository import MedicationRepository
from app.repositories.timeline_repository import TimelineRepository
from app.services.profile_context import resolve_user_profile
from app.schemas.medications import MedicationLogCreateRequest, MedicationLogResponse
from app.services.audit_service import AuditService


class MedicationAdherenceService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = MedicationRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.audit_service = AuditService(db)

    def list_logs(self, user: User) -> list[MedicationLogResponse]:
        profile = self._require_profile(user)
        logs = self.repository.list_logs_for_patient(profile.id)
        return [self._to_response(log) for log in logs]

    def log_medication(
        self,
        user: User,
        medication_id: UUID,
        payload: MedicationLogCreateRequest,
    ) -> MedicationLogResponse:
        profile = self._require_profile(user)
        medication = self.repository.get_for_patient(profile.id, medication_id)
        if medication is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")

        scheduled_at = payload.scheduled_at or utcnow()
        if scheduled_at.tzinfo is None:
            scheduled_at = scheduled_at.replace(tzinfo=timezone.utc)

        taken_at = payload.taken_at
        if payload.status == MedicationLogStatus.TAKEN and taken_at is None:
            taken_at = utcnow()
        elif taken_at is not None and taken_at.tzinfo is None:
            taken_at = taken_at.replace(tzinfo=timezone.utc)

        log = MedicationLog(
            medication_id=medication.id,
            scheduled_at=scheduled_at,
            taken_at=taken_at,
            status=payload.status,
            notes=payload.notes,
        )
        self.repository.add_log(log)
        self.db.flush()
        self.timeline_repository.add(
            TimelineEvent(
                patient_id=profile.id,
                event_type=TimelineEventType.MEDICATION_LOGGED,
                source_type="medication_log",
                source_id=log.id,
                title=f"Aderenza terapia: {medication.name}",
                description=self._timeline_description(medication.name, log.status, log.notes),
                event_date=taken_at or scheduled_at,
            )
        )
        self.audit_service.log_for_user(
            user,
            event_type="medication_logged",
            entity_type="medication_log",
            entity_id=log.id,
            summary=f"Aderenza registrata per {medication.name}",
            metadata={"status": log.status.value},
        )

        from app.services.notification_service import NotificationService

        NotificationService(self.db).sync_medication_notifications_for_patient(profile.id)
        self.db.commit()
        self.db.refresh(log)
        return self._to_response(log)

    @staticmethod
    def _to_response(log: MedicationLog) -> MedicationLogResponse:
        return MedicationLogResponse(
            id=log.id,
            medication_id=log.medication.id,
            medication_name=log.medication.name,
            medication_dosage=log.medication.dosage,
            scheduled_at=log.scheduled_at,
            taken_at=log.taken_at,
            status=log.status,
            notes=log.notes,
        )

    @staticmethod
    def _timeline_description(name: str, status: MedicationLogStatus, notes: str | None) -> str:
        base = {
            MedicationLogStatus.TAKEN: f"Assunzione registrata per {name}.",
            MedicationLogStatus.SKIPPED: f"Dose saltata per {name}.",
            MedicationLogStatus.MISSED: f"Dose non confermata per {name}.",
        }[status]
        if notes:
            return f"{base} Note: {notes}"
        return base

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile
