from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, utcnow


class VitalSignEntry(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "vital_sign_entries"

    daily_entry_id: Mapped[str] = mapped_column(ForeignKey("daily_entries.id", ondelete="CASCADE"))
    type: Mapped[str] = mapped_column(String(255), nullable=False)
    value: Mapped[str] = mapped_column(String(255), nullable=False)
    unit: Mapped[str | None] = mapped_column(String(64))
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    daily_entry = relationship("DailyEntry", back_populates="vitals")

