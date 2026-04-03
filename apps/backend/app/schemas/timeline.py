from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.enums import TimelineEventType, TimelineSeverity


class TimelineEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    event_type: TimelineEventType
    source_type: str
    source_id: UUID | None
    title: str
    description: str
    event_date: datetime
    severity: TimelineSeverity | None

