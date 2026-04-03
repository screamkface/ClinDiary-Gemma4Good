from __future__ import annotations

from sqlalchemy import ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class SymptomEntry(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "symptom_entries"

    daily_entry_id: Mapped[str] = mapped_column(ForeignKey("daily_entries.id", ondelete="CASCADE"))
    symptom_code: Mapped[str] = mapped_column(String(255), nullable=False)
    severity: Mapped[int | None] = mapped_column(Integer)
    duration_minutes: Mapped[int | None] = mapped_column(Integer)
    body_location: Mapped[str | None] = mapped_column(String(255))
    metadata_json: Mapped[dict | None] = mapped_column(JSON, default=dict)

    daily_entry = relationship("DailyEntry", back_populates="symptoms")

