from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class NotificationPreference(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "notification_preferences"

    patient_id: Mapped[str] = mapped_column(
        ForeignKey("patient_profiles.id", ondelete="CASCADE"),
        unique=True,
    )
    in_app_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    daily_checkin_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    medication_reminders_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    screening_reminders_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    document_follow_up_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    report_ready_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    clinical_alerts_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    prevention_tips_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    push_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    email_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    email_address: Mapped[str | None] = mapped_column(String(255))

    patient = relationship("PatientProfile", back_populates="notification_preferences")
