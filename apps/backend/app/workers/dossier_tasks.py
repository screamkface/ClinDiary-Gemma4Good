from app.core.database import SessionLocal
from app.services.dossier_service import DossierService
from app.workers.celery_app import celery_app


@celery_app.task(name="dossier.cleanup_expired_share_links")
def cleanup_expired_share_links_task() -> dict[str, int]:
    with SessionLocal() as db:
        removed = DossierService(db).cleanup_expired_share_links()
        return {"removed": removed}
