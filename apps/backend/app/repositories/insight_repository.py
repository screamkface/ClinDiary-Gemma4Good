from datetime import date
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.ai_summary import AiSummary
from app.models.enums import AiSummaryType


class InsightRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_period(
        self,
        *,
        patient_id: UUID,
        summary_type: AiSummaryType,
        period_start: date,
        period_end: date,
    ) -> AiSummary | None:
        stmt = select(AiSummary).where(
            AiSummary.patient_id == patient_id,
            AiSummary.summary_type == summary_type,
            AiSummary.period_start == period_start,
            AiSummary.period_end == period_end,
        )
        return self.db.scalar(stmt)

    def add(self, summary: AiSummary) -> AiSummary:
        self.db.add(summary)
        return summary

    def list_between(
        self,
        *,
        patient_id: UUID,
        start_date: date,
        end_date: date,
        summary_type: AiSummaryType | None = None,
    ) -> list[AiSummary]:
        stmt = (
            select(AiSummary)
            .where(
                AiSummary.patient_id == patient_id,
                AiSummary.period_end >= start_date,
                AiSummary.period_end <= end_date,
            )
            .order_by(AiSummary.period_end.asc(), AiSummary.generated_at.asc())
        )
        if summary_type is not None:
            stmt = stmt.where(AiSummary.summary_type == summary_type)
        return list(self.db.scalars(stmt))

    def list_summary_dates_between(
        self,
        *,
        patient_id: UUID,
        summary_type: AiSummaryType,
        start_date: date,
        end_date: date,
    ) -> list[date]:
        stmt = (
            select(AiSummary.period_start)
            .where(
                AiSummary.patient_id == patient_id,
                AiSummary.summary_type == summary_type,
                AiSummary.period_start >= start_date,
                AiSummary.period_start <= end_date,
            )
            .order_by(AiSummary.period_start.asc())
        )
        return list(self.db.scalars(stmt))

    def find_covering_date(
        self,
        *,
        patient_id: UUID,
        summary_type: AiSummaryType,
        reference_date: date,
    ) -> AiSummary | None:
        stmt = (
            select(AiSummary)
            .where(
                AiSummary.patient_id == patient_id,
                AiSummary.summary_type == summary_type,
                AiSummary.period_start <= reference_date,
                AiSummary.period_end >= reference_date,
            )
            .order_by(AiSummary.generated_at.desc(), AiSummary.created_at.desc())
        )
        return self.db.scalar(stmt)
