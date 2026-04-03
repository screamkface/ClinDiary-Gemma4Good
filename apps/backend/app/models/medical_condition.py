from __future__ import annotations

from datetime import date

from sqlalchemy import Date, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import ConditionStatus


class MedicalCondition(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "medical_conditions"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    diagnosis_date: Mapped[date | None] = mapped_column(Date)
    status: Mapped[ConditionStatus | None] = mapped_column(
        db_enum(ConditionStatus, "condition_status")
    )
    notes: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="conditions")
