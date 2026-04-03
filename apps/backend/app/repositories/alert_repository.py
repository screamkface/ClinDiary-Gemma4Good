from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.alert import Alert
from app.models.enums import AlertStatus


class AlertRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_for_patient(self, patient_id: UUID, *, status: AlertStatus | None = None) -> list[Alert]:
        stmt = select(Alert).where(Alert.patient_id == patient_id)
        if status is not None:
            stmt = stmt.where(Alert.status == status)
        stmt = stmt.order_by(Alert.triggered_at.desc(), Alert.created_at.desc())
        return list(self.db.scalars(stmt))

    def get_for_patient(self, patient_id: UUID, alert_id: UUID) -> Alert | None:
        stmt = select(Alert).where(Alert.patient_id == patient_id, Alert.id == alert_id)
        return self.db.scalar(stmt)

    def get_open_by_rule(
        self,
        *,
        patient_id: UUID,
        rule_code: str,
        source_type: str,
        source_id: UUID,
    ) -> Alert | None:
        stmt = select(Alert).where(
            Alert.patient_id == patient_id,
            Alert.rule_code == rule_code,
            Alert.source_type == source_type,
            Alert.source_id == source_id,
            Alert.status == AlertStatus.OPEN,
        )
        return self.db.scalar(stmt)

    def add(self, alert: Alert) -> Alert:
        self.db.add(alert)
        return alert
