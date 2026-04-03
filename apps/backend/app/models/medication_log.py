from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import MedicationLogStatus


class MedicationLog(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "medication_logs"

    medication_id: Mapped[str] = mapped_column(ForeignKey("medications.id", ondelete="CASCADE"))
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    taken_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[MedicationLogStatus] = mapped_column(
        db_enum(MedicationLogStatus, "medication_log_status"),
        nullable=False,
    )
    notes: Mapped[str | None] = mapped_column(Text)

    medication = relationship("Medication", back_populates="logs")
