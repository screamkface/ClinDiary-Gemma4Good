from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class WearableDailySummarySyncItem(BaseModel):
    summary_date: date
    source_platform: str = Field(min_length=1, max_length=64)
    source_name: str | None = Field(default=None, max_length=255)
    source_device_model: str | None = Field(default=None, max_length=255)
    steps_count: int | None = Field(default=None, ge=0)
    active_energy_kcal: float | None = Field(default=None, ge=0)
    exercise_minutes: float | None = Field(default=None, ge=0)
    distance_meters: float | None = Field(default=None, ge=0)
    sleep_minutes: float | None = Field(default=None, ge=0)
    sleep_deep_minutes: float | None = Field(default=None, ge=0)
    sleep_rem_minutes: float | None = Field(default=None, ge=0)
    heart_rate_avg_bpm: float | None = Field(default=None, ge=0)
    heart_rate_min_bpm: float | None = Field(default=None, ge=0)
    heart_rate_max_bpm: float | None = Field(default=None, ge=0)
    resting_heart_rate_bpm: float | None = Field(default=None, ge=0)
    blood_oxygen_avg_pct: float | None = Field(default=None, ge=0, le=100)
    hrv_sdnn_ms: float | None = Field(default=None, ge=0)
    record_count: int | None = Field(default=None, ge=0)

    def has_any_metric(self) -> bool:
        return any(
            value is not None
            for value in (
                self.steps_count,
                self.active_energy_kcal,
                self.exercise_minutes,
                self.distance_meters,
                self.sleep_minutes,
                self.sleep_deep_minutes,
                self.sleep_rem_minutes,
                self.heart_rate_avg_bpm,
                self.heart_rate_min_bpm,
                self.heart_rate_max_bpm,
                self.resting_heart_rate_bpm,
                self.blood_oxygen_avg_pct,
                self.hrv_sdnn_ms,
            )
        )


class WearableDailySummarySyncRequest(BaseModel):
    items: list[WearableDailySummarySyncItem]


class WearableDailySummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    summary_date: date
    source_platform: str
    source_name: str | None
    source_device_model: str | None
    steps_count: int | None
    active_energy_kcal: float | None
    exercise_minutes: float | None
    distance_meters: float | None
    sleep_minutes: float | None
    sleep_deep_minutes: float | None
    sleep_rem_minutes: float | None
    heart_rate_avg_bpm: float | None
    heart_rate_min_bpm: float | None
    heart_rate_max_bpm: float | None
    resting_heart_rate_bpm: float | None
    blood_oxygen_avg_pct: float | None
    hrv_sdnn_ms: float | None
    record_count: int
    synced_at: datetime


class WearableDailySummarySyncResponse(BaseModel):
    synced_count: int
    items: list[WearableDailySummaryResponse]
