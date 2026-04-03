from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import AlertSeverity, AlertStatus


class AlertResolveRequest(BaseModel):
    resolution_notes: str | None = Field(default=None, max_length=2000)


class AlertResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    severity: AlertSeverity
    alert_type: str
    rule_code: str | None
    title: str
    description: str
    status: AlertStatus
    source_type: str | None
    source_id: UUID | None
    triggered_at: datetime
    resolved_at: datetime | None
    resolution_notes: str | None
