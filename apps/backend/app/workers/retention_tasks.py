from __future__ import annotations

from app.core.database import SessionLocal
from app.core.logging import logger
from app.services.retention_service import RetentionService
from app.workers.celery_app import celery_app


@celery_app.task(name="retention.cleanup_all")
def cleanup_all_retention_data() -> dict[str, int]:
    db = SessionLocal()
    try:
        results = RetentionService(db).cleanup_all()
        logger.info("retention.cleanup_completed", **results)
        return results
    finally:
        db.close()
