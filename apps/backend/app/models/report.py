from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum, utcnow
from app.models.enums import ReportStatus, ReportType


class Report(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "reports"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    report_type: Mapped[ReportType] = mapped_column(
        db_enum(ReportType, "report_type"),
        nullable=False,
    )
    status: Mapped[ReportStatus] = mapped_column(
        db_enum(ReportStatus, "report_status"),
        default=ReportStatus.GENERATED,
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    summary_excerpt: Mapped[str | None] = mapped_column(Text)
    content_text: Mapped[str] = mapped_column(Text, nullable=False)
    file_url: Mapped[str] = mapped_column(String(512), nullable=False)
    processing_error: Mapped[str | None] = mapped_column(Text)
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    patient = relationship("PatientProfile", back_populates="reports")
