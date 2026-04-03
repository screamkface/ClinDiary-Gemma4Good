from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, utcnow


class NotificationDeviceToken(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "notification_device_tokens"
    __table_args__ = (
        UniqueConstraint("patient_id", "device_token", name="uq_notification_device_token_patient_token"),
    )

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    platform: Mapped[str] = mapped_column(String(50), nullable=False)
    device_token: Mapped[str] = mapped_column(String(512), nullable=False)
    device_label: Mapped[str | None] = mapped_column(String(255))
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    patient = relationship("PatientProfile", back_populates="notification_device_tokens")
