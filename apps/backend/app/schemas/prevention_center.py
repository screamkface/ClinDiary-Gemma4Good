from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from app.models.enums import BiologicalSex


class PreventionCenterOverviewResponse(BaseModel):
    actionable_screenings: int
    vaccine_reviews: int
    vaccine_registry_items: int
    pregnancy_items: int
    shared_decision_items: int
    seasonal_checks: int
    follow_up_items: int


class PreventionRecommendationResponse(BaseModel):
    code: str
    title: str
    subtitle: str | None = None
    reason: str | None = None
    action_hint: str | None = None
    cadence_label: str | None = None
    status: str
    priority: str
    category: str
    kind: str
    source_type: str | None = None
    source_id: UUID | None = None


class PreventionCenterResponse(BaseModel):
    generated_at: datetime
    display_name: str
    age: int | None
    biological_sex: BiologicalSex | None
    region_code: str | None = None
    region_name: str | None = None
    overview: PreventionCenterOverviewResponse
    annual_visit: PreventionRecommendationResponse | None
    visits_and_controls: list[PreventionRecommendationResponse]
    vaccines: list[PreventionRecommendationResponse]
    vaccine_registry: list[PreventionRecommendationResponse]
    pregnancy_and_preconception: list[PreventionRecommendationResponse]
    shared_decisions: list[PreventionRecommendationResponse]
    seasonal_checks: list[PreventionRecommendationResponse]
    follow_up_reminders: list[PreventionRecommendationResponse]
