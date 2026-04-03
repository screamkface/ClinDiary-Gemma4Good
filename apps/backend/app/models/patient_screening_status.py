from __future__ import annotations

from datetime import date

from sqlalchemy import Date, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import ScreeningStatus


class PatientScreeningStatus(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "patient_screening_status"
    __table_args__ = (
        UniqueConstraint(
            "patient_id",
            "screening_program_id",
            name="uq_patient_screening_program",
        ),
    )

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    screening_program_id: Mapped[str] = mapped_column(
        ForeignKey("screening_programs.id", ondelete="CASCADE")
    )
    last_done_date: Mapped[date | None] = mapped_column(Date)
    next_due_date: Mapped[date | None] = mapped_column(Date)
    status: Mapped[ScreeningStatus] = mapped_column(
        db_enum(ScreeningStatus, "screening_status"),
        nullable=False,
        default=ScreeningStatus.NEVER_DONE,
    )
    recommendation_reason: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="screening_statuses")
    screening_program = relationship("ScreeningProgram", back_populates="patient_statuses")
    screening_notifications = relationship(
        "ScreeningNotification",
        back_populates="screening_status",
        cascade="all, delete-orphan",
    )
