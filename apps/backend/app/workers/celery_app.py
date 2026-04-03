from datetime import timedelta

from celery import Celery
from celery.schedules import crontab

from app.core.config import get_settings


settings = get_settings()
celery_app = Celery("clindiary", broker=settings.redis_url, backend=settings.redis_url)
celery_app.conf.task_default_queue = "clindiary"
celery_app.conf.task_always_eager = settings.celery_task_always_eager
celery_app.conf.task_eager_propagates = settings.celery_task_eager_propagates
celery_app.conf.imports = (
    "app.workers.dossier_tasks",
    "app.workers.document_tasks",
    "app.workers.notification_tasks",
    "app.workers.retention_tasks",
    "app.workers.summary_tasks",
)
celery_app.conf.beat_schedule = {
    "sync-notifications": {
        "task": "notifications.sync_all",
        "schedule": timedelta(minutes=settings.notification_sync_interval_minutes),
    },
    "sync-daily-summaries": {
        "task": "insights.sync_daily",
        "schedule": crontab(minute=15, hour=21),
    },
    "sync-weekly-summaries": {
        "task": "insights.sync_weekly",
        "schedule": crontab(minute=30, hour=21, day_of_week="sun"),
    },
    "sync-monthly-summaries": {
        "task": "insights.sync_monthly",
        "schedule": crontab(minute=45, hour=21, day_of_month="1"),
    },
    "cleanup-expired-dossier-share-links": {
        "task": "dossier.cleanup_expired_share_links",
        "schedule": crontab(minute=10, hour=2),
    },
    "cleanup-retention-data": {
        "task": "retention.cleanup_all",
        "schedule": crontab(minute=20, hour=2),
    },
}


def worker_main() -> None:
    celery_app.worker_main(["worker", "--loglevel=info"])


def beat_main() -> None:
    celery_app.worker_main(["beat", "--loglevel=info"])
