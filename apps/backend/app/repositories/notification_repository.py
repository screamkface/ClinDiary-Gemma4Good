from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.notification import Notification


class NotificationRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_active_for_patient(self, patient_id: UUID) -> list[Notification]:
        stmt = (
            select(Notification)
            .where(Notification.patient_id == patient_id, Notification.is_active.is_(True))
            .order_by(Notification.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def list_active_for_patients(self, patient_ids: list[UUID]) -> list[Notification]:
        if not patient_ids:
            return []
        stmt = (
            select(Notification)
            .where(
                Notification.patient_id.in_(patient_ids),
                Notification.is_active.is_(True),
            )
            .order_by(Notification.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def get_for_patient(self, patient_id: UUID, notification_id: UUID) -> Notification | None:
        stmt = select(Notification).where(
            Notification.patient_id == patient_id,
            Notification.id == notification_id,
        )
        return self.db.scalar(stmt)

    def get_for_patients(
        self,
        patient_ids: list[UUID],
        notification_id: UUID,
    ) -> Notification | None:
        if not patient_ids:
            return None
        stmt = select(Notification).where(
            Notification.patient_id.in_(patient_ids),
            Notification.id == notification_id,
        )
        return self.db.scalar(stmt)

    def get_by_dedupe(self, patient_id: UUID, dedupe_key: str) -> Notification | None:
        stmt = select(Notification).where(
            Notification.patient_id == patient_id,
            Notification.dedupe_key == dedupe_key,
        )
        return self.db.scalar(stmt)

    def add(self, notification: Notification) -> Notification:
        self.db.add(notification)
        return notification
