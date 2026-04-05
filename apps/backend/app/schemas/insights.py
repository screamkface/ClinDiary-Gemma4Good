from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.enums import AiSummaryType


class InsightSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    summary_type: AiSummaryType
    period_start: date
    period_end: date
    content: str
    provider_name: str | None
    model_name: str | None
    generated_at: datetime


class LocalInsightRuntimeStatusResponse(BaseModel):
    enabled: bool
    provider: str
    active_provider_label: str
    runtime_mode: str
    backend: str | None
    model_name: str | None
    configured_base_url_present: bool
    fallback_provider: str
    is_cloud_bypassed_for_this_request: bool


class OnDeviceInsightPromptResponse(BaseModel):
    summary_type: AiSummaryType
    period_start: date
    period_end: date
    system_prompt: str
    user_prompt: str
    provider_name: str
    suggested_model_family: str
    is_cloud_bypassed_for_this_request: bool
