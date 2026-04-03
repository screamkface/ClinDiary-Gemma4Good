from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.timeline_event import TimelineEvent


class TimelineRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_for_patient(self, patient_id: UUID) -> list[TimelineEvent]:
        stmt = (
            select(TimelineEvent)
            .where(TimelineEvent.patient_id == patient_id)
            .order_by(TimelineEvent.event_date.desc(), TimelineEvent.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def list_for_patient_between(
        self,
        patient_id: UUID,
        start_at: datetime,
        end_at: datetime,
    ) -> list[TimelineEvent]:
        stmt = (
            select(TimelineEvent)
            .where(
                TimelineEvent.patient_id == patient_id,
                TimelineEvent.event_date >= start_at,
                TimelineEvent.event_date < end_at,
            )
            .order_by(TimelineEvent.event_date.desc(), TimelineEvent.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def add(self, event: TimelineEvent) -> TimelineEvent:
        self.db.add(event)
        return event

    def find_by_source(self, source_type: str, source_id: UUID) -> TimelineEvent | None:
        stmt = select(TimelineEvent).where(
            TimelineEvent.source_type == source_type,
            TimelineEvent.source_id == source_id,
        )
        return self.db.scalar(stmt)

    def delete_by_source(self, source_type: str, source_id: UUID) -> None:
        event = self.find_by_source(source_type, source_id)
        if event is not None:
            self.db.delete(event)

    def upsert_source_event(
        self,
        *,
        patient_id: UUID,
        source_type: str,
        source_id: UUID,
        event_type,
        title: str,
        description: str,
        event_date: datetime,
        severity=None,
    ) -> TimelineEvent:
        event = self.find_by_source(source_type, source_id)
        if event is None:
            event = TimelineEvent(
                patient_id=patient_id,
                source_type=source_type,
                source_id=source_id,
                event_type=event_type,
                title=title,
                description=description,
                event_date=event_date,
                severity=severity,
            )
            self.db.add(event)
            return event

        event.event_type = event_type
        event.title = title
        event.description = description
        event.event_date = event_date
        event.severity = severity
        return event
