from __future__ import annotations

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class FamilyHistoryEntry(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "family_history_entries"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    relation: Mapped[str] = mapped_column(String(255), nullable=False)
    condition_name: Mapped[str] = mapped_column(String(255), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="family_history_entries")

