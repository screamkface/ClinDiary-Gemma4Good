from __future__ import annotations

from datetime import date

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.user import User
from app.models.wearable_daily_summary import WearableDailySummary
from app.repositories.wearable_repository import WearableRepository
from app.services.profile_context import resolve_user_profile
from app.schemas.wearables import (
    WearableDailySummaryResponse,
    WearableDailySummarySyncItem,
    WearableDailySummarySyncRequest,
    WearableDailySummarySyncResponse,
)


class WearableService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.wearable_repository = WearableRepository(db)

    def sync_daily_summaries(
        self,
        user: User,
        payload: WearableDailySummarySyncRequest,
    ) -> WearableDailySummarySyncResponse:
        profile = self._require_profile(user)
        synced: list[WearableDailySummary] = []
        merged_items = self._merge_items_by_date(payload.items)

        for item in merged_items:
            if not item.has_any_metric():
                continue

            summary = self.wearable_repository.get_by_date(profile.id, item.summary_date)
            if summary is None:
                summary = WearableDailySummary(
                    patient_id=profile.id,
                    summary_date=item.summary_date,
                    source_platform=item.source_platform.strip().lower(),
                )
                self.wearable_repository.add(summary)

            self._apply_item(summary, item)
            synced.append(summary)

        self.db.commit()
        for item in synced:
            self.db.refresh(item)

        return WearableDailySummarySyncResponse(
            synced_count=len(synced),
            items=[WearableDailySummaryResponse.model_validate(item) for item in synced],
        )

    @staticmethod
    def _merge_items_by_date(
        items: list[WearableDailySummarySyncItem],
    ) -> list[WearableDailySummarySyncItem]:
        merged: dict[date, WearableDailySummarySyncItem] = {}

        for item in items:
            existing = merged.get(item.summary_date)
            if existing is None:
                merged[item.summary_date] = item
                continue

            merged[item.summary_date] = existing.model_copy(
                update={
                    "source_platform": item.source_platform or existing.source_platform,
                    "source_name": item.source_name or existing.source_name,
                    "source_device_model": item.source_device_model or existing.source_device_model,
                    "steps_count": item.steps_count
                    if item.steps_count is not None
                    else existing.steps_count,
                    "active_energy_kcal": item.active_energy_kcal
                    if item.active_energy_kcal is not None
                    else existing.active_energy_kcal,
                    "exercise_minutes": item.exercise_minutes
                    if item.exercise_minutes is not None
                    else existing.exercise_minutes,
                    "distance_meters": item.distance_meters
                    if item.distance_meters is not None
                    else existing.distance_meters,
                    "sleep_minutes": item.sleep_minutes
                    if item.sleep_minutes is not None
                    else existing.sleep_minutes,
                    "sleep_deep_minutes": item.sleep_deep_minutes
                    if item.sleep_deep_minutes is not None
                    else existing.sleep_deep_minutes,
                    "sleep_rem_minutes": item.sleep_rem_minutes
                    if item.sleep_rem_minutes is not None
                    else existing.sleep_rem_minutes,
                    "heart_rate_avg_bpm": item.heart_rate_avg_bpm
                    if item.heart_rate_avg_bpm is not None
                    else existing.heart_rate_avg_bpm,
                    "heart_rate_min_bpm": item.heart_rate_min_bpm
                    if item.heart_rate_min_bpm is not None
                    else existing.heart_rate_min_bpm,
                    "heart_rate_max_bpm": item.heart_rate_max_bpm
                    if item.heart_rate_max_bpm is not None
                    else existing.heart_rate_max_bpm,
                    "resting_heart_rate_bpm": item.resting_heart_rate_bpm
                    if item.resting_heart_rate_bpm is not None
                    else existing.resting_heart_rate_bpm,
                    "blood_oxygen_avg_pct": item.blood_oxygen_avg_pct
                    if item.blood_oxygen_avg_pct is not None
                    else existing.blood_oxygen_avg_pct,
                    "hrv_sdnn_ms": item.hrv_sdnn_ms
                    if item.hrv_sdnn_ms is not None
                    else existing.hrv_sdnn_ms,
                    "record_count": (existing.record_count or 0)
                    + (item.record_count or 0),
                }
            )

        return list(merged.values())

    def list_recent_summaries(self, user: User, *, days: int = 30) -> list[WearableDailySummary]:
        profile = self._require_profile(user)
        safe_days = max(1, min(days, 90))
        return self.wearable_repository.list_recent_for_patient(profile.id, limit=safe_days)

    def get_day_summary(
        self,
        user: User,
        *,
        target_date: date,
    ) -> WearableDailySummary | None:
        profile = self._require_profile(user)
        return self.wearable_repository.get_by_date(profile.id, target_date)

    @staticmethod
    def _apply_item(summary: WearableDailySummary, item: WearableDailySummarySyncItem) -> None:
        summary.source_platform = item.source_platform.strip().lower()
        summary.source_name = item.source_name
        summary.source_device_model = item.source_device_model
        summary.steps_count = item.steps_count
        summary.active_energy_kcal = item.active_energy_kcal
        summary.exercise_minutes = item.exercise_minutes
        summary.distance_meters = item.distance_meters
        summary.sleep_minutes = item.sleep_minutes
        summary.sleep_deep_minutes = item.sleep_deep_minutes
        summary.sleep_rem_minutes = item.sleep_rem_minutes
        summary.heart_rate_avg_bpm = item.heart_rate_avg_bpm
        summary.heart_rate_min_bpm = item.heart_rate_min_bpm
        summary.heart_rate_max_bpm = item.heart_rate_max_bpm
        summary.resting_heart_rate_bpm = item.resting_heart_rate_bpm
        summary.blood_oxygen_avg_pct = item.blood_oxygen_avg_pct
        summary.hrv_sdnn_ms = item.hrv_sdnn_ms
        summary.record_count = item.record_count or 0
        summary.synced_at = utcnow()

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile
