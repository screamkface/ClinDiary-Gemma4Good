from datetime import date
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.daily_entry import DailyEntry
from app.models.symptom_entry import SymptomEntry
from app.models.vital_sign_entry import VitalSignEntry


class DailyEntryRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_for_patient(self, patient_id: UUID) -> list[DailyEntry]:
        stmt = (
            select(DailyEntry)
            .options(joinedload(DailyEntry.symptoms), joinedload(DailyEntry.vitals))
            .where(DailyEntry.patient_id == patient_id)
            .order_by(DailyEntry.entry_date.desc(), DailyEntry.created_at.desc())
        )
        return list(self.db.scalars(stmt).unique())

    def list_for_patient_between(self, patient_id: UUID, start_date: date, end_date: date) -> list[DailyEntry]:
        stmt = (
            select(DailyEntry)
            .options(joinedload(DailyEntry.symptoms), joinedload(DailyEntry.vitals))
            .where(
                DailyEntry.patient_id == patient_id,
                DailyEntry.entry_date >= start_date,
                DailyEntry.entry_date <= end_date,
            )
            .order_by(DailyEntry.entry_date.desc(), DailyEntry.created_at.desc())
        )
        return list(self.db.scalars(stmt).unique())

    def get_for_patient(self, patient_id: UUID, entry_id: UUID) -> DailyEntry | None:
        stmt = (
            select(DailyEntry)
            .options(joinedload(DailyEntry.symptoms), joinedload(DailyEntry.vitals))
            .where(DailyEntry.patient_id == patient_id, DailyEntry.id == entry_id)
        )
        return self.db.scalar(stmt)

    def get_by_date(self, patient_id: UUID, entry_date: date) -> DailyEntry | None:
        stmt = (
            select(DailyEntry)
            .options(joinedload(DailyEntry.symptoms), joinedload(DailyEntry.vitals))
            .where(
                DailyEntry.patient_id == patient_id,
                DailyEntry.entry_date == entry_date,
            )
        )
        return self.db.scalar(stmt)

    def add(self, entry: DailyEntry) -> DailyEntry:
        self.db.add(entry)
        return entry

    def add_symptom(self, symptom: SymptomEntry) -> SymptomEntry:
        self.db.add(symptom)
        return symptom

    def add_vital(self, vital: VitalSignEntry) -> VitalSignEntry:
        self.db.add(vital)
        return vital

    def delete(self, entry: DailyEntry) -> None:
        self.db.delete(entry)
