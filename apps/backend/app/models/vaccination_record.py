from __future__ import annotations

from datetime import date

from sqlalchemy import Date, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class VaccinationRecord(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "vaccination_records"

    patient_id: Mapped[str] = mapped_column(
        ForeignKey("patient_profiles.id", ondelete="CASCADE")
    )
    vaccine_name: Mapped[str] = mapped_column(String(255), nullable=False)
    administered_on: Mapped[date | None] = mapped_column(Date)
    dose_number: Mapped[int | None] = mapped_column(Integer)
    next_due_date: Mapped[date | None] = mapped_column(Date)
    provider_name: Mapped[str | None] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="vaccination_records")
