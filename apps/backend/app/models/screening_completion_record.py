from __future__ import annotations

from datetime import date

from sqlalchemy import Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class ScreeningCompletionRecord(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "screening_completion_records"
    __table_args__ = (
        UniqueConstraint(
            "patient_id",
            "screening_program_id",
            "completed_on",
            name="uq_screening_completion_patient_program_date",
        ),
    )

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    screening_program_id: Mapped[str] = mapped_column(
        ForeignKey("screening_programs.id", ondelete="CASCADE")
    )
    completed_on: Mapped[date] = mapped_column(Date, nullable=False)

    patient = relationship("PatientProfile", back_populates="screening_completion_records")
    screening_program = relationship("ScreeningProgram", back_populates="completion_records")
