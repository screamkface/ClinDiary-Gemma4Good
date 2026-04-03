from __future__ import annotations

from datetime import date
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.wearable_daily_summary import WearableDailySummary


class WearableRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_date(self, patient_id: UUID, summary_date: date) -> WearableDailySummary | None:
        stmt = select(WearableDailySummary).where(
            WearableDailySummary.patient_id == patient_id,
            WearableDailySummary.summary_date == summary_date,
        )
        return self.db.scalar(stmt)

    def list_recent_for_patient(
        self,
        patient_id: UUID,
        *,
        limit: int,
    ) -> list[WearableDailySummary]:
        stmt = (
            select(WearableDailySummary)
            .where(WearableDailySummary.patient_id == patient_id)
            .order_by(WearableDailySummary.summary_date.desc())
            .limit(limit)
        )
        return list(self.db.scalars(stmt))

    def list_for_patient_between(
        self,
        patient_id: UUID,
        start_date: date,
        end_date: date,
    ) -> list[WearableDailySummary]:
        stmt = (
            select(WearableDailySummary)
            .where(
                WearableDailySummary.patient_id == patient_id,
                WearableDailySummary.summary_date >= start_date,
                WearableDailySummary.summary_date <= end_date,
            )
            .order_by(WearableDailySummary.summary_date.asc())
        )
        return list(self.db.scalars(stmt))

    def add(self, summary: WearableDailySummary) -> WearableDailySummary:
        self.db.add(summary)
        return summary
