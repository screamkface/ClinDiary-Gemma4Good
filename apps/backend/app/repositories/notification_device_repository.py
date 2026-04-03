from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.notification_device_token import NotificationDeviceToken


class NotificationDeviceRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_for_patient(self, patient_id: UUID) -> list[NotificationDeviceToken]:
        stmt = (
            select(NotificationDeviceToken)
            .where(
                NotificationDeviceToken.patient_id == patient_id,
                NotificationDeviceToken.active.is_(True),
            )
            .order_by(NotificationDeviceToken.updated_at.desc())
        )
        return list(self.db.scalars(stmt))

    def get_by_token(
        self,
        patient_id: UUID,
        token: str,
    ) -> NotificationDeviceToken | None:
        stmt = select(NotificationDeviceToken).where(
            NotificationDeviceToken.patient_id == patient_id,
            NotificationDeviceToken.device_token == token,
        )
        return self.db.scalar(stmt)

    def add(self, item: NotificationDeviceToken) -> NotificationDeviceToken:
        self.db.add(item)
        return item
