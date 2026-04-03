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
