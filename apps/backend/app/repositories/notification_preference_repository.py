from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.notification_preference import NotificationPreference


class NotificationPreferenceRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_for_patient(self, patient_id: UUID) -> NotificationPreference | None:
        stmt = select(NotificationPreference).where(NotificationPreference.patient_id == patient_id)
        return self.db.scalar(stmt)

    def add(self, preferences: NotificationPreference) -> NotificationPreference:
        self.db.add(preferences)
        return preferences
