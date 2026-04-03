from datetime import date

from pydantic import BaseModel

from app.schemas.daily_entries import DailyEntryResponse
from app.schemas.documents import DocumentUploadResponse
from app.schemas.insights import InsightSummaryResponse
from app.schemas.timeline import TimelineEventResponse
from app.schemas.wearables import WearableDailySummaryResponse


class HistoryDayResponse(BaseModel):
    target_date: date
    daily_entry: DailyEntryResponse | None
    daily_summary: InsightSummaryResponse | None
    weekly_summary: InsightSummaryResponse | None = None
    monthly_summary: InsightSummaryResponse | None = None
    wearable_summary: WearableDailySummaryResponse | None = None
    documents: list[DocumentUploadResponse]
    timeline_events: list[TimelineEventResponse]


class HistoryActivityDaysResponse(BaseModel):
    activity_dates: list[date]
