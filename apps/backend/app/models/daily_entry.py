from __future__ import annotations

from datetime import date

from sqlalchemy import Date, ForeignKey, Integer, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class DailyEntry(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "daily_entries"
    __table_args__ = (UniqueConstraint("patient_id", "entry_date", name="uq_daily_entry_patient_date"),)

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    entry_date: Mapped[date] = mapped_column(Date, nullable=False)
    sleep_hours: Mapped[float | None]
    sleep_quality: Mapped[int | None] = mapped_column(Integer)
    energy_level: Mapped[int | None] = mapped_column(Integer)
    mood_level: Mapped[int | None] = mapped_column(Integer)
    stress_level: Mapped[int | None] = mapped_column(Integer)
    appetite_level: Mapped[int | None] = mapped_column(Integer)
    hydration_level: Mapped[int | None] = mapped_column(Integer)
    general_pain: Mapped[int | None] = mapped_column(Integer)
    general_notes: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="daily_entries")
    symptoms = relationship(
        "SymptomEntry",
        back_populates="daily_entry",
        cascade="all, delete-orphan",
    )
    vitals = relationship(
        "VitalSignEntry",
        back_populates="daily_entry",
        cascade="all, delete-orphan",
    )

