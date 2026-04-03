from datetime import date

from app.core.database import SessionLocal
from app.models.enums import AiSummaryType
from app.services.insight_service import InsightService
from app.workers.celery_app import celery_app


def _parse_reference_date(reference_date: str | None) -> date | None:
    if reference_date is None:
        return None
    return date.fromisoformat(reference_date)


@celery_app.task(name="insights.sync_daily")
def sync_daily_summaries_task(reference_date: str | None = None) -> dict[str, int | str]:
    with SessionLocal() as db:
        return InsightService(db).sync_due_summaries(
            AiSummaryType.DAILY,
            reference_date=_parse_reference_date(reference_date),
        )


@celery_app.task(name="insights.sync_weekly")
def sync_weekly_summaries_task(reference_date: str | None = None) -> dict[str, int | str]:
    with SessionLocal() as db:
        return InsightService(db).sync_due_summaries(
            AiSummaryType.WEEKLY,
            reference_date=_parse_reference_date(reference_date),
        )


@celery_app.task(name="insights.sync_monthly")
def sync_monthly_summaries_task(reference_date: str | None = None) -> dict[str, int | str]:
    with SessionLocal() as db:
        return InsightService(db).sync_due_summaries(
            AiSummaryType.MONTHLY,
            reference_date=_parse_reference_date(reference_date),
        )
