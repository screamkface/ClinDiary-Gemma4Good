from __future__ import annotations

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import AllergySeverity


class Allergy(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "allergies"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    allergen: Mapped[str] = mapped_column(String(255), nullable=False)
    severity: Mapped[AllergySeverity | None] = mapped_column(
        db_enum(AllergySeverity, "allergy_severity")
    )
    notes: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="allergies")
