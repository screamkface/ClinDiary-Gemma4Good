from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class ScreeningNotification(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "screening_notifications"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    screening_program_id: Mapped[str] = mapped_column(
        ForeignKey("screening_programs.id", ondelete="CASCADE")
    )
    patient_screening_status_id: Mapped[str] = mapped_column(
        ForeignKey("patient_screening_status.id", ondelete="CASCADE")
    )
    notification_id: Mapped[str | None] = mapped_column(ForeignKey("notifications.id", ondelete="SET NULL"))
    scheduled_for: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    patient = relationship("PatientProfile", back_populates="screening_notifications")
    screening_program = relationship("ScreeningProgram", back_populates="screening_notifications")
    screening_status = relationship("PatientScreeningStatus", back_populates="screening_notifications")
    notification = relationship("Notification", back_populates="screening_notifications")
