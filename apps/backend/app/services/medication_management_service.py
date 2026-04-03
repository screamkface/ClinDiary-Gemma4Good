from __future__ import annotations

from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.enums import TimelineEventType
from app.models.medication import Medication
from app.models.medication_schedule import MedicationSchedule
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.repositories.medication_repository import MedicationRepository
from app.repositories.timeline_repository import TimelineRepository
from app.services.profile_context import resolve_user_profile
from app.services.audit_service import AuditService


class MedicationManagementService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = MedicationRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.audit_service = AuditService(db)

    def update_medication(self, user: User, medication_id: UUID, payload) -> Medication:
        profile = self._require_profile(user)
        medication = self._require_medication(profile.id, medication_id)
        previous_active = medication.active
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(medication, field, value)

        if previous_active != medication.active:
            self.timeline_repository.upsert_source_event(
                patient_id=profile.id,
                source_type="medication",
                source_id=medication.id,
                event_type=(
                    TimelineEventType.MEDICATION_STARTED
                    if medication.active
                    else TimelineEventType.MEDICATION_STOPPED
                ),
                title=f"Terapia aggiornata: {medication.name}",
                description=(
                    f"La terapia {medication.name} e stata riattivata."
                    if medication.active
                    else f"La terapia {medication.name} e stata sospesa."
                ),
                event_date=utcnow(),
            )

        self.audit_service.log_for_user(
            user,
            event_type="medication_updated",
            entity_type="medication",
            entity_id=medication.id,
            summary=f"Terapia aggiornata: {medication.name}",
            metadata=payload.model_dump(exclude_unset=True),
        )
        self._commit_and_sync(profile.id)
        return self._require_medication(profile.id, medication_id)

    def add_schedule(self, user: User, medication_id: UUID, payload) -> Medication:
        profile = self._require_profile(user)
        medication = self._require_medication(profile.id, medication_id)
        payload_data = payload.model_dump()
        days_of_week = payload_data.pop("days_of_week", [])
        medication.schedules.append(
            MedicationSchedule(
                days_of_week_csv=",".join(str(day) for day in days_of_week) or None,
                **payload_data,
            )
        )
        self.audit_service.log_for_user(
            user,
            event_type="medication_schedule_added",
            entity_type="medication",
            entity_id=medication.id,
            summary=f"Nuovo orario terapia per {medication.name}",
        )
        self._commit_and_sync(profile.id)
        return self._require_medication(profile.id, medication_id)

    def update_schedule(
        self,
        user: User,
        medication_id: UUID,
        schedule_id: UUID,
        payload,
    ) -> Medication:
        profile = self._require_profile(user)
        medication = self._require_medication(profile.id, medication_id)
        schedule = self._require_schedule(profile.id, medication_id, schedule_id)
        data = payload.model_dump(exclude_unset=True)
        if "days_of_week" in data:
            schedule.days_of_week_csv = ",".join(str(day) for day in data.pop("days_of_week") or []) or None
        for field, value in data.items():
            setattr(schedule, field, value)

        self.audit_service.log_for_user(
            user,
            event_type="medication_schedule_updated",
            entity_type="medication_schedule",
            entity_id=schedule.id,
            summary=f"Orario terapia aggiornato per {medication.name}",
            metadata=payload.model_dump(exclude_unset=True),
        )
        self._commit_and_sync(profile.id)
        return self._require_medication(profile.id, medication_id)

    def pause_schedule(
        self,
        user: User,
        medication_id: UUID,
        schedule_id: UUID,
        *,
        paused_until,
    ) -> Medication:
        profile = self._require_profile(user)
        medication = self._require_medication(profile.id, medication_id)
        schedule = self._require_schedule(profile.id, medication_id, schedule_id)
        schedule.paused_until = paused_until
        schedule.active = True
        self.audit_service.log_for_user(
            user,
            event_type="medication_schedule_paused",
            entity_type="medication_schedule",
            entity_id=schedule.id,
            summary=f"Orario terapia messo in pausa per {medication.name}",
            metadata={"paused_until": paused_until},
        )
        self._commit_and_sync(profile.id)
        return self._require_medication(profile.id, medication_id)

    def resume_schedule(self, user: User, medication_id: UUID, schedule_id: UUID) -> Medication:
        profile = self._require_profile(user)
        medication = self._require_medication(profile.id, medication_id)
        schedule = self._require_schedule(profile.id, medication_id, schedule_id)
        schedule.paused_until = None
        schedule.active = True
        self.audit_service.log_for_user(
            user,
            event_type="medication_schedule_resumed",
            entity_type="medication_schedule",
            entity_id=schedule.id,
            summary=f"Orario terapia riattivato per {medication.name}",
        )
        self._commit_and_sync(profile.id)
        return self._require_medication(profile.id, medication_id)

    def delete_schedule(self, user: User, medication_id: UUID, schedule_id: UUID) -> Medication:
        profile = self._require_profile(user)
        medication = self._require_medication(profile.id, medication_id)
        schedule = self._require_schedule(profile.id, medication_id, schedule_id)
        self.db.delete(schedule)
        self.audit_service.log_for_user(
            user,
            event_type="medication_schedule_deleted",
            entity_type="medication_schedule",
            entity_id=schedule.id,
            summary=f"Orario terapia rimosso per {medication.name}",
        )
        self._commit_and_sync(profile.id)
        return self._require_medication(profile.id, medication_id)

    def _commit_and_sync(self, patient_id: UUID) -> None:
        from app.services.notification_service import NotificationService

        NotificationService(self.db).sync_medication_notifications_for_patient(patient_id)
        self.db.commit()

    def _require_medication(self, patient_id: UUID, medication_id: UUID) -> Medication:
        medication = self.repository.get_for_patient(patient_id, medication_id)
        if medication is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")
        return medication

    def _require_schedule(self, patient_id: UUID, medication_id: UUID, schedule_id: UUID) -> MedicationSchedule:
        schedule = self.repository.get_schedule_for_patient(patient_id, medication_id, schedule_id)
        if schedule is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication schedule not found")
        return schedule

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile
