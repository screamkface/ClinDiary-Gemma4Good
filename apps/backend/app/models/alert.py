from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum, utcnow
from app.models.enums import AlertSeverity, AlertStatus


class Alert(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "alerts"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    severity: Mapped[AlertSeverity] = mapped_column(
        db_enum(AlertSeverity, "alert_severity"),
        nullable=False,
    )
    alert_type: Mapped[str] = mapped_column(String(100), nullable=False)
    rule_code: Mapped[str | None] = mapped_column(String(100))
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[AlertStatus] = mapped_column(
        db_enum(AlertStatus, "alert_status"),
        default=AlertStatus.OPEN,
        nullable=False,
    )
    source_type: Mapped[str | None] = mapped_column(String(100))
    source_id: Mapped[str | None] = mapped_column(Uuid)
    triggered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    resolution_notes: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="alerts")
