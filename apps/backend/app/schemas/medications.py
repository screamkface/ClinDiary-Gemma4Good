from datetime import date, datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import MedicationLogStatus


class MedicationScheduleCreateRequest(BaseModel):
    scheduled_time: time
    days_of_week: list[int] = Field(default_factory=list)
    start_date: date | None = None
    end_date: date | None = None
    cycle_days_on: int | None = Field(default=None, ge=1)
    cycle_days_off: int | None = Field(default=None, ge=1)
    paused_until: date | None = None
    instructions: str | None = Field(default=None, max_length=255)
    active: bool = True

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.end_date and self.start_date and self.end_date < self.start_date:
            raise ValueError("end_date must be after start_date")
        if any(day < 0 or day > 6 for day in self.days_of_week):
            raise ValueError("days_of_week must contain values between 0 and 6")
        if (self.cycle_days_on is None) ^ (self.cycle_days_off is None):
            raise ValueError("cycle_days_on and cycle_days_off must be provided together")
        return self


class MedicationScheduleUpdateRequest(BaseModel):
    scheduled_time: time | None = None
    days_of_week: list[int] | None = None
    start_date: date | None = None
    end_date: date | None = None
    cycle_days_on: int | None = Field(default=None, ge=1)
    cycle_days_off: int | None = Field(default=None, ge=1)
    paused_until: date | None = None
    instructions: str | None = Field(default=None, max_length=255)
    active: bool | None = None

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.end_date and self.start_date and self.end_date < self.start_date:
            raise ValueError("end_date must be after start_date")
        if self.days_of_week is not None and any(day < 0 or day > 6 for day in self.days_of_week):
            raise ValueError("days_of_week must contain values between 0 and 6")
        if (self.cycle_days_on is None) ^ (self.cycle_days_off is None):
            raise ValueError("cycle_days_on and cycle_days_off must be provided together")
        return self


class MedicationScheduleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    scheduled_time: time
    days_of_week: list[int] = Field(default_factory=list)
    start_date: date | None
    end_date: date | None
    cycle_days_on: int | None
    cycle_days_off: int | None
    paused_until: date | None
    instructions: str | None
    active: bool


class MedicationDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    dosage: str | None
    frequency: str | None
    route: str | None
    start_date: date | None
    end_date: date | None
    active: bool
    notes: str | None
    schedules: list[MedicationScheduleResponse] = Field(default_factory=list)


class MedicationUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    dosage: str | None = None
    frequency: str | None = None
    route: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    active: bool | None = None
    notes: str | None = None


class MedicationSchedulePauseRequest(BaseModel):
    paused_until: date


class MedicationLogCreateRequest(BaseModel):
    scheduled_at: datetime | None = None
    taken_at: datetime | None = None
    status: MedicationLogStatus = MedicationLogStatus.TAKEN
    notes: str | None = None


class MedicationLogResponse(BaseModel):
    id: UUID
    medication_id: UUID
    medication_name: str
    medication_dosage: str | None
    scheduled_at: datetime
    taken_at: datetime | None
    status: MedicationLogStatus
    notes: str | None
