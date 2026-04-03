from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.medication import Medication
from app.models.medication_log import MedicationLog
from app.models.medication_schedule import MedicationSchedule


class MedicationRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_for_patient(self, patient_id: UUID) -> list[Medication]:
        stmt = (
            select(Medication)
            .options(joinedload(Medication.schedules))
            .where(Medication.patient_id == patient_id)
            .order_by(Medication.created_at.desc())
        )
        return list(self.db.scalars(stmt).unique())

    def get_for_patient(self, patient_id: UUID, medication_id: UUID) -> Medication | None:
        stmt = (
            select(Medication)
            .options(joinedload(Medication.schedules))
            .where(Medication.patient_id == patient_id, Medication.id == medication_id)
        )
        return self.db.scalars(stmt).unique().first()

    def get_schedule_for_patient(
        self,
        patient_id: UUID,
        medication_id: UUID,
        schedule_id: UUID,
    ) -> MedicationSchedule | None:
        stmt = (
            select(MedicationSchedule)
            .join(Medication)
            .where(
                Medication.patient_id == patient_id,
                Medication.id == medication_id,
                MedicationSchedule.id == schedule_id,
            )
        )
        return self.db.scalar(stmt)

    def add_schedule(self, schedule: MedicationSchedule) -> MedicationSchedule:
        self.db.add(schedule)
        return schedule

    def list_logs_for_patient(self, patient_id: UUID) -> list[MedicationLog]:
        stmt = (
            select(MedicationLog)
            .options(
                joinedload(MedicationLog.medication).joinedload(Medication.schedules),
            )
            .join(Medication)
            .where(Medication.patient_id == patient_id)
            .order_by(MedicationLog.scheduled_at.desc(), MedicationLog.created_at.desc())
        )
        return list(self.db.scalars(stmt).unique())

    def list_logs_for_patient_between(
        self,
        patient_id: UUID,
        start_at: datetime,
        end_at: datetime,
    ) -> list[MedicationLog]:
        stmt = (
            select(MedicationLog)
            .options(joinedload(MedicationLog.medication))
            .join(Medication)
            .where(
                Medication.patient_id == patient_id,
                MedicationLog.scheduled_at >= start_at,
                MedicationLog.scheduled_at <= end_at,
            )
            .order_by(MedicationLog.scheduled_at.desc())
        )
        return list(self.db.scalars(stmt).unique())

    def add_log(self, log: MedicationLog) -> MedicationLog:
        self.db.add(log)
        return log
