from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.report import Report


class ReportRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def add(self, report: Report) -> Report:
        self.db.add(report)
        return report

    def get_for_patient(self, patient_id: UUID, report_id: UUID) -> Report | None:
        stmt = select(Report).where(Report.patient_id == patient_id, Report.id == report_id)
        return self.db.scalar(stmt)

    def get_by_id(self, report_id: UUID) -> Report | None:
        stmt = select(Report).where(Report.id == report_id)
        return self.db.scalar(stmt)

    def list_recent_for_patient(self, patient_id: UUID, *, limit: int = 10) -> list[Report]:
        stmt = (
            select(Report)
            .where(Report.patient_id == patient_id)
            .order_by(Report.generated_at.desc(), Report.created_at.desc())
            .limit(limit)
        )
        return list(self.db.scalars(stmt))

    def list_all_for_patient(self, patient_id: UUID) -> list[Report]:
        stmt = (
            select(Report)
            .where(Report.patient_id == patient_id)
            .order_by(Report.generated_at.desc(), Report.created_at.desc())
        )
        return list(self.db.scalars(stmt))
