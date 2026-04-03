from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.user import User
from app.repositories.daily_entry_repository import DailyEntryRepository
from app.repositories.document_repository import DocumentRepository
from app.repositories.insight_repository import InsightRepository
from app.repositories.timeline_repository import TimelineRepository
from app.repositories.wearable_repository import WearableRepository
from app.services.billing_service import BillingService
from app.schemas.history import HistoryActivityDaysResponse, HistoryDayResponse
from app.services.insight_service import InsightService
from app.services.profile_context import resolve_user_profile
from app.models.enums import AiSummaryType


class HistoryService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.daily_entry_repository = DailyEntryRepository(db)
        self.document_repository = DocumentRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.wearable_repository = WearableRepository(db)
        self.insight_repository = InsightRepository(db)
        self.insight_service = InsightService(db)
        self.billing_service = BillingService(db)

    def get_day_overview(
        self,
        user: User,
        *,
        target_date: date,
        include_rollups: bool = False,
    ) -> HistoryDayResponse:
        profile = self._require_profile(user)
        daily_entry = self.daily_entry_repository.get_by_date(profile.id, target_date)
        daily_summary = (
            self.insight_service.get_daily_summary(user, reference_date=target_date)
            if self.insight_service.can_access_summary(user, AiSummaryType.DAILY)
            else None
        )
        weekly_summary = (
            self.insight_service.get_weekly_summary(user, reference_date=target_date)
            if include_rollups and self.insight_service.can_access_summary(user, AiSummaryType.WEEKLY)
            else None
        )
        monthly_summary = (
            self.insight_service.get_monthly_summary(user, reference_date=target_date)
            if include_rollups and self.insight_service.can_access_summary(user, AiSummaryType.MONTHLY)
            else None
        )

        documents = [
            document
            for document in self.document_repository.list_for_patient(profile.id)
            if (document.exam_date or document.upload_date.date()) == target_date
        ]
        wearable_summary = self.wearable_repository.get_by_date(profile.id, target_date)
        day_start = datetime.combine(target_date, time.min, tzinfo=timezone.utc)
        day_end = datetime.combine(target_date + timedelta(days=1), time.min, tzinfo=timezone.utc)
        timeline_events = self.timeline_repository.list_for_patient_between(profile.id, day_start, day_end)

        return HistoryDayResponse(
            target_date=target_date,
            daily_entry=daily_entry,
            daily_summary=daily_summary,
            weekly_summary=weekly_summary,
            monthly_summary=monthly_summary,
            wearable_summary=wearable_summary,
            documents=documents,
            timeline_events=timeline_events,
        )

    def list_activity_dates(
        self,
        user: User,
        *,
        start_date: date,
        end_date: date,
    ) -> HistoryActivityDaysResponse:
        profile = self._require_profile(user)
        activity_dates: set[date] = set()

        for entry in self.daily_entry_repository.list_for_patient_between(
            profile.id,
            start_date,
            end_date,
        ):
            activity_dates.add(entry.entry_date)

        for summary_date in self.insight_repository.list_summary_dates_between(
            patient_id=profile.id,
            summary_type=AiSummaryType.DAILY,
            start_date=start_date,
            end_date=end_date,
        ):
            activity_dates.add(summary_date)

        for document in self.document_repository.list_for_patient(profile.id):
            document_date = document.exam_date or document.upload_date.date()
            if start_date <= document_date <= end_date:
                activity_dates.add(document_date)

        for wearable_summary in self.wearable_repository.list_for_patient_between(
            profile.id,
            start_date,
            end_date,
        ):
            activity_dates.add(wearable_summary.summary_date)

        timeline_start = datetime.combine(start_date, time.min, tzinfo=timezone.utc)
        timeline_end = datetime.combine(end_date + timedelta(days=1), time.min, tzinfo=timezone.utc)
        for event in self.timeline_repository.list_for_patient_between(
            profile.id,
            timeline_start,
            timeline_end,
        ):
            activity_dates.add(event.event_date.date())

        return HistoryActivityDaysResponse(
            activity_dates=sorted(activity_dates),
        )

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile
