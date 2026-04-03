from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class SymptomEntryCreateRequest(BaseModel):
    symptom_code: str = Field(min_length=1, max_length=255)
    severity: int | None = Field(default=None, ge=0, le=10)
    duration_minutes: int | None = Field(default=None, ge=0)
    body_location: str | None = Field(default=None, max_length=255)
    metadata_json: dict | None = None


class SymptomEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    symptom_code: str
    severity: int | None
    duration_minutes: int | None
    body_location: str | None
    metadata_json: dict | None


class VitalSignEntryCreateRequest(BaseModel):
    type: str = Field(min_length=1, max_length=255)
    value: str = Field(min_length=1, max_length=255)
    unit: str | None = Field(default=None, max_length=64)
    measured_at: datetime | None = None


class VitalSignEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    type: str
    value: str
    unit: str | None
    measured_at: datetime


class DailyEntryCreateRequest(BaseModel):
    entry_date: date
    sleep_hours: float | None = Field(default=None, ge=0, le=24)
    sleep_quality: int | None = Field(default=None, ge=0, le=10)
    energy_level: int | None = Field(default=None, ge=0, le=10)
    mood_level: int | None = Field(default=None, ge=0, le=10)
    stress_level: int | None = Field(default=None, ge=0, le=10)
    appetite_level: int | None = Field(default=None, ge=0, le=10)
    hydration_level: int | None = Field(default=None, ge=0, le=10)
    general_pain: int | None = Field(default=None, ge=0, le=10)
    general_notes: str | None = None


class DailyEntryUpdateRequest(BaseModel):
    sleep_hours: float | None = Field(default=None, ge=0, le=24)
    sleep_quality: int | None = Field(default=None, ge=0, le=10)
    energy_level: int | None = Field(default=None, ge=0, le=10)
    mood_level: int | None = Field(default=None, ge=0, le=10)
    stress_level: int | None = Field(default=None, ge=0, le=10)
    appetite_level: int | None = Field(default=None, ge=0, le=10)
    hydration_level: int | None = Field(default=None, ge=0, le=10)
    general_pain: int | None = Field(default=None, ge=0, le=10)
    general_notes: str | None = None


class DailyEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    entry_date: date
    sleep_hours: float | None
    sleep_quality: int | None
    energy_level: int | None
    mood_level: int | None
    stress_level: int | None
    appetite_level: int | None
    hydration_level: int | None
    general_pain: int | None
    general_notes: str | None
    symptoms: list[SymptomEntryResponse]
    vitals: list[VitalSignEntryResponse]

