from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, utcnow


class WearableDailySummary(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "wearable_daily_summaries"
    __table_args__ = (
        UniqueConstraint("patient_id", "summary_date", name="uq_wearable_daily_summary_patient_date"),
    )

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    summary_date: Mapped[date] = mapped_column(Date, nullable=False)
    source_platform: Mapped[str] = mapped_column(String(64), nullable=False)
    source_name: Mapped[str | None] = mapped_column(String(255))
    source_device_model: Mapped[str | None] = mapped_column(String(255))
    steps_count: Mapped[int | None] = mapped_column(Integer)
    active_energy_kcal: Mapped[float | None] = mapped_column(Float)
    exercise_minutes: Mapped[float | None] = mapped_column(Float)
    distance_meters: Mapped[float | None] = mapped_column(Float)
    sleep_minutes: Mapped[float | None] = mapped_column(Float)
    sleep_deep_minutes: Mapped[float | None] = mapped_column(Float)
    sleep_rem_minutes: Mapped[float | None] = mapped_column(Float)
    heart_rate_avg_bpm: Mapped[float | None] = mapped_column(Float)
    heart_rate_min_bpm: Mapped[float | None] = mapped_column(Float)
    heart_rate_max_bpm: Mapped[float | None] = mapped_column(Float)
    resting_heart_rate_bpm: Mapped[float | None] = mapped_column(Float)
    blood_oxygen_avg_pct: Mapped[float | None] = mapped_column(Float)
    hrv_sdnn_ms: Mapped[float | None] = mapped_column(Float)
    record_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    synced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    patient = relationship("PatientProfile", back_populates="wearable_daily_summaries")
