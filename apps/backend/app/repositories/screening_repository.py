from __future__ import annotations

from uuid import UUID

from datetime import date

from sqlalchemy import delete, select
from sqlalchemy.orm import Session, joinedload

from app.models.screening_completion_record import ScreeningCompletionRecord
from app.models.patient_screening_status import PatientScreeningStatus
from app.models.regional_screening_availability import RegionalScreeningAvailability
from app.models.screening_notification import ScreeningNotification
from app.models.screening_program import ScreeningProgram
from app.models.screening_rule import ScreeningRule


class ScreeningRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_programs(self) -> list[ScreeningProgram]:
        stmt = (
            select(ScreeningProgram)
            .options(
                joinedload(ScreeningProgram.rules),
                joinedload(ScreeningProgram.regional_availability),
            )
            .order_by(ScreeningProgram.category.asc(), ScreeningProgram.name.asc())
        )
        return list(self.db.scalars(stmt).unique())

    def get_program_by_code(self, code: str) -> ScreeningProgram | None:
        stmt = (
            select(ScreeningProgram)
            .options(
                joinedload(ScreeningProgram.rules),
                joinedload(ScreeningProgram.regional_availability),
            )
            .where(ScreeningProgram.code == code)
        )
        return self.db.scalar(stmt)

    def add_program(self, program: ScreeningProgram) -> ScreeningProgram:
        self.db.add(program)
        return program

    def add_rule(self, rule: ScreeningRule) -> ScreeningRule:
        self.db.add(rule)
        return rule

    def add_availability(self, availability: RegionalScreeningAvailability) -> RegionalScreeningAvailability:
        self.db.add(availability)
        return availability

    def list_statuses_for_patient(self, patient_id: UUID) -> list[PatientScreeningStatus]:
        stmt = (
            select(PatientScreeningStatus)
            .options(
                joinedload(PatientScreeningStatus.screening_program).joinedload(
                    ScreeningProgram.regional_availability
                ),
                joinedload(PatientScreeningStatus.screening_program).joinedload(ScreeningProgram.rules),
            )
            .where(PatientScreeningStatus.patient_id == patient_id)
            .order_by(PatientScreeningStatus.next_due_date.asc(), PatientScreeningStatus.created_at.desc())
        )
        return list(self.db.scalars(stmt).unique())

    def get_status_for_patient(
        self,
        patient_id: UUID,
        status_id: UUID,
    ) -> PatientScreeningStatus | None:
        stmt = (
            select(PatientScreeningStatus)
            .options(
                joinedload(PatientScreeningStatus.screening_program).joinedload(
                    ScreeningProgram.regional_availability
                ),
            )
            .where(
                PatientScreeningStatus.patient_id == patient_id,
                PatientScreeningStatus.id == status_id,
            )
        )
        return self.db.scalar(stmt)

    def get_status_by_program(
        self,
        patient_id: UUID,
        screening_program_id: UUID,
    ) -> PatientScreeningStatus | None:
        stmt = select(PatientScreeningStatus).where(
            PatientScreeningStatus.patient_id == patient_id,
            PatientScreeningStatus.screening_program_id == screening_program_id,
        )
        return self.db.scalar(stmt)

    def add_status(self, status_item: PatientScreeningStatus) -> PatientScreeningStatus:
        self.db.add(status_item)
        return status_item

    def add_completion_record(self, item: ScreeningCompletionRecord) -> ScreeningCompletionRecord:
        self.db.add(item)
        return item

    def get_completion_record_for_date(
        self,
        patient_id: UUID,
        screening_program_id: UUID,
        completed_on: date,
    ) -> ScreeningCompletionRecord | None:
        stmt = select(ScreeningCompletionRecord).where(
            ScreeningCompletionRecord.patient_id == patient_id,
            ScreeningCompletionRecord.screening_program_id == screening_program_id,
            ScreeningCompletionRecord.completed_on == completed_on,
        )
        return self.db.scalar(stmt)

    def get_latest_completion_date(
        self,
        patient_id: UUID,
        screening_program_id: UUID,
    ) -> date | None:
        stmt = (
            select(ScreeningCompletionRecord.completed_on)
            .where(
                ScreeningCompletionRecord.patient_id == patient_id,
                ScreeningCompletionRecord.screening_program_id == screening_program_id,
            )
            .order_by(ScreeningCompletionRecord.completed_on.desc())
            .limit(1)
        )
        return self.db.scalar(stmt)

    def list_current_year_completion_dates(
        self,
        patient_id: UUID,
        *,
        year_start: date,
        year_end: date,
    ) -> dict[UUID, date]:
        stmt = (
            select(
                ScreeningCompletionRecord.screening_program_id,
                ScreeningCompletionRecord.completed_on,
            )
            .where(
                ScreeningCompletionRecord.patient_id == patient_id,
                ScreeningCompletionRecord.completed_on >= year_start,
                ScreeningCompletionRecord.completed_on <= year_end,
            )
            .order_by(
                ScreeningCompletionRecord.screening_program_id.asc(),
                ScreeningCompletionRecord.completed_on.desc(),
            )
        )
        result: dict[UUID, date] = {}
        for screening_program_id, completed_on in self.db.execute(stmt):
            result.setdefault(screening_program_id, completed_on)
        return result

    def delete_completion_records_in_range(
        self,
        patient_id: UUID,
        screening_program_id: UUID,
        *,
        start_date: date,
        end_date: date,
    ) -> int:
        stmt = delete(ScreeningCompletionRecord).where(
            ScreeningCompletionRecord.patient_id == patient_id,
            ScreeningCompletionRecord.screening_program_id == screening_program_id,
            ScreeningCompletionRecord.completed_on >= start_date,
            ScreeningCompletionRecord.completed_on <= end_date,
        )
        result = self.db.execute(stmt)
        return result.rowcount or 0

    def list_screening_notifications(self, patient_id: UUID) -> list[ScreeningNotification]:
        stmt = (
            select(ScreeningNotification)
            .where(ScreeningNotification.patient_id == patient_id)
            .order_by(ScreeningNotification.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def get_screening_notification(
        self,
        patient_id: UUID,
        status_id: UUID,
    ) -> ScreeningNotification | None:
        stmt = select(ScreeningNotification).where(
            ScreeningNotification.patient_id == patient_id,
            ScreeningNotification.patient_screening_status_id == status_id,
        )
        return self.db.scalar(stmt)

    def add_screening_notification(self, item: ScreeningNotification) -> ScreeningNotification:
        self.db.add(item)
        return item
