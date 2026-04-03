from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum, utcnow
from app.models.enums import AiSummaryType


class AiSummary(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "ai_summaries"
    __table_args__ = (
        UniqueConstraint(
            "patient_id",
            "summary_type",
            "period_start",
            "period_end",
            name="uq_ai_summary_patient_type_period",
        ),
    )

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    summary_type: Mapped[AiSummaryType] = mapped_column(
        db_enum(AiSummaryType, "ai_summary_type"),
        nullable=False,
    )
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    provider_name: Mapped[str | None] = mapped_column(String(64))
    model_name: Mapped[str | None] = mapped_column(String(128))
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    patient = relationship("PatientProfile", back_populates="ai_summaries")
