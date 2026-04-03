from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import BiologicalSex, ScreeningStatus


class RegionalAvailabilityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    region_code: str
    region_name: str
    booking_url: str | None
    notes: str | None
    active: bool


class ScreeningCatalogItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    code: str
    name: str
    description: str
    min_age: int | None
    max_age: int | None
    target_sex: BiologicalSex | None
    interval_months: int | None
    public_coverage_flag: bool
    category: str
    care_pathway: str
    recommendation_level: str
    cadence_label: str | None
    catalog_only: bool
    explanation: str | None
    active: bool
    regional_availability: list[RegionalAvailabilityResponse]


class PatientScreeningStatusResponse(BaseModel):
    id: UUID
    screening_program_id: UUID
    screening_code: str
    screening_name: str
    screening_category: str
    care_pathway: str
    recommendation_level: str
    cadence_label: str | None
    public_coverage_flag: bool
    explanation: str | None
    recommendation_reason: str | None
    last_done_date: date | None
    next_due_date: date | None
    completed_this_year: bool
    current_year_last_completed_on: date | None
    status: ScreeningStatus
    regional_availability: list[RegionalAvailabilityResponse]


class ScreeningMarkDoneRequest(BaseModel):
    done_date: date = Field(default_factory=date.today)


class ScreeningRecomputeResponse(BaseModel):
    generated_at: datetime
    items: list[PatientScreeningStatusResponse]
