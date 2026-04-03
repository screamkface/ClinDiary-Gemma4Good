from app.core.database import SessionLocal
from app.services.notification_service import NotificationService
from app.workers.celery_app import celery_app


@celery_app.task(name="notifications.sync_all")
def sync_notifications_task() -> dict[str, int]:
    with SessionLocal() as db:
        synced_patients = NotificationService(db).sync_all_patients()
    return {"synced_patients": synced_patients}
