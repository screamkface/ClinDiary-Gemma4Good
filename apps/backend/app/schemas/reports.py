from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.enums import ReportStatus, ReportType


class ReportGenerateRequest(BaseModel):
    report_type: ReportType
    reference_date: date | None = None


class ReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    report_type: ReportType
    status: ReportStatus
    title: str
    period_start: date
    period_end: date
    summary_excerpt: str | None
    content_text: str
    generated_at: datetime
    processing_error: str | None
    download_url: str | None = None
