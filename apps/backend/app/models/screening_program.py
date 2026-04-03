from __future__ import annotations

from sqlalchemy import Boolean, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import BiologicalSex


class ScreeningProgram(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "screening_programs"

    code: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    min_age: Mapped[int | None] = mapped_column(Integer)
    max_age: Mapped[int | None] = mapped_column(Integer)
    target_sex: Mapped[BiologicalSex | None] = mapped_column(
        db_enum(BiologicalSex, "biological_sex"),
    )
    interval_months: Mapped[int | None] = mapped_column(Integer)
    public_coverage_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    recommendation_level: Mapped[str] = mapped_column(String(32), nullable=False, default="routine")
    cadence_label: Mapped[str | None] = mapped_column(String(120))
    catalog_only: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    explanation: Mapped[str | None] = mapped_column(Text)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    rules = relationship(
        "ScreeningRule",
        back_populates="screening_program",
        cascade="all, delete-orphan",
    )
    patient_statuses = relationship(
        "PatientScreeningStatus",
        back_populates="screening_program",
        cascade="all, delete-orphan",
    )
    completion_records = relationship(
        "ScreeningCompletionRecord",
        back_populates="screening_program",
        cascade="all, delete-orphan",
    )
    regional_availability = relationship(
        "RegionalScreeningAvailability",
        back_populates="screening_program",
        cascade="all, delete-orphan",
    )
    screening_notifications = relationship(
        "ScreeningNotification",
        back_populates="screening_program",
        cascade="all, delete-orphan",
    )
