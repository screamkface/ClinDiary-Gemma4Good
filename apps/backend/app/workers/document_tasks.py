from uuid import UUID

from app.core.database import SessionLocal
from app.repositories.document_repository import DocumentRepository
from app.services.document_rag_service import DocumentRagService
from app.services.document_service import DocumentService
from app.workers.celery_app import celery_app


@celery_app.task(name="documents.process")
def process_document_task(document_id: str) -> None:
    with SessionLocal() as db:
        DocumentService(db).process_document(UUID(document_id))


@celery_app.task(name="documents.reindex")
def reindex_document_task(document_id: str) -> None:
    with SessionLocal() as db:
        DocumentRagService(db).reindex_document(UUID(document_id))
        db.commit()


@celery_app.task(name="documents.reindex_patient")
def reindex_patient_documents_task(patient_id: str) -> None:
    with SessionLocal() as db:
        repository = DocumentRepository(db)
        documents = repository.list_for_patient(UUID(patient_id))
        rag_service = DocumentRagService(db)
        for document in documents:
            rag_service.reindex_document(document.id)
        db.commit()
