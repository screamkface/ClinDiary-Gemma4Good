from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import TimelineEventType, TimelineSeverity


class TimelineEvent(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "timeline_events"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    event_type: Mapped[TimelineEventType] = mapped_column(
        db_enum(TimelineEventType, "timeline_event_type"),
        nullable=False,
    )
    source_type: Mapped[str] = mapped_column(String(255), nullable=False)
    source_id: Mapped[str | None] = mapped_column(Uuid)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    event_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    severity: Mapped[TimelineSeverity | None] = mapped_column(
        db_enum(TimelineSeverity, "timeline_severity")
    )

    patient = relationship("PatientProfile", back_populates="timeline_events")
