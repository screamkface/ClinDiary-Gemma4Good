from __future__ import annotations

from datetime import date, time

from sqlalchemy import Boolean, Date, ForeignKey, Integer, String, Time
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class MedicationSchedule(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "medication_schedules"

    medication_id: Mapped[str] = mapped_column(ForeignKey("medications.id", ondelete="CASCADE"))
    scheduled_time: Mapped[time] = mapped_column(Time, nullable=False)
    days_of_week_csv: Mapped[str | None] = mapped_column("days_of_week", String(32))
    start_date: Mapped[date | None] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)
    cycle_days_on: Mapped[int | None] = mapped_column(Integer)
    cycle_days_off: Mapped[int | None] = mapped_column(Integer)
    paused_until: Mapped[date | None] = mapped_column(Date)
    instructions: Mapped[str | None] = mapped_column(String(255))
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    medication = relationship("Medication", back_populates="schedules")

    @property
    def days_of_week(self) -> list[int]:
        if not self.days_of_week_csv:
            return []
        return [int(item) for item in self.days_of_week_csv.split(",") if item != ""]
