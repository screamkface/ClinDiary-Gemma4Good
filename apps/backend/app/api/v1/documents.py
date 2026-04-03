from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.enums import ClinicalDocumentType
from app.models.user import User
from app.schemas.documents import (
    DocumentArchiveResponse,
    DocumentDetailResponse,
    DocumentFolderCreateRequest,
    DocumentFolderResponse,
    DocumentMoveRequest,
    DocumentMoveResponse,
    DocumentQueryRequest,
    DocumentQueryResponse,
    DocumentReindexResponse,
    DocumentProcessResponse,
    DocumentReviewRequest,
    DocumentReviewResponse,
    DocumentStatusUpdateRequest,
    DocumentStatusUpdateResponse,
    DocumentUploadForm,
    DocumentUploadResponse,
)
from app.services.billing_service import BillingFeatureCode, BillingService
from app.services.document_service import DocumentService
from app.services.document_rag_service import DocumentRagService


router = APIRouter(prefix="/documents", tags=["documents"])


def _require_cloud_document_storage(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    BillingService(db).require_feature(
        user,
        BillingFeatureCode.CLOUD_DOCUMENT_STORAGE,
        message=(
            "L'archivio documenti cloud richiede ClinDiary AI Plus. "
            "Sul piano free i file restano salvati solo sul dispositivo."
        ),
    )


def _parse_upload_form(
    title: Annotated[str | None, Form()] = None,
    document_type: Annotated[ClinicalDocumentType | None, Form()] = None,
    exam_date: Annotated[date | None, Form()] = None,
    source: Annotated[str | None, Form()] = None,
    folder_id: Annotated[UUID | None, Form()] = None,
) -> DocumentUploadForm:
    return DocumentUploadForm(
        title=title,
        document_type=document_type,
        exam_date=exam_date,
        source=source,
        folder_id=folder_id,
    )


@router.post("/upload", response_model=DocumentUploadResponse, status_code=status.HTTP_201_CREATED)
def upload_document(
    payload: Annotated[DocumentUploadForm, Depends(_parse_upload_form)],
    file: Annotated[UploadFile, File(...)],
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DocumentService(db).upload_document(user, payload=payload, file=file)


@router.get("", response_model=list[DocumentUploadResponse])
def list_documents(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DocumentService(db).list_documents(user)


@router.get("/archive", response_model=DocumentArchiveResponse)
def get_document_archive(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    folder_id: Annotated[UUID | None, Query()] = None,
    query: Annotated[str | None, Query(max_length=120)] = None,
):
    return DocumentService(db).list_archive(user, folder_id=folder_id, query=query)


@router.get("/folders", response_model=list[DocumentFolderResponse])
def list_document_folders(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DocumentService(db).list_folders(user)


@router.post("/folders", response_model=DocumentFolderResponse, status_code=status.HTTP_201_CREATED)
def create_document_folder(
    payload: DocumentFolderCreateRequest,
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DocumentService(db).create_folder(user, payload=payload)


@router.post("/query", response_model=DocumentQueryResponse)
def query_documents(
    payload: DocumentQueryRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DocumentRagService(db).answer_question(user, payload=payload)


@router.post("/reindex", response_model=DocumentReindexResponse)
def reindex_documents(
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    queued_documents = DocumentService(db).enqueue_patient_reindex(user)
    return DocumentReindexResponse(
        message="Document reindex scheduled",
        queued_documents=queued_documents,
    )


@router.get("/{document_id}", response_model=DocumentDetailResponse)
def get_document(
    document_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = DocumentService(db)
    document = service.get_document(user, document_id)
    return service.build_detail_response(user, document)


@router.post("/{document_id}/process", response_model=DocumentProcessResponse)
def process_document(
    document_id: UUID,
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = DocumentService(db)
    document = service.enqueue_processing(user, document_id)
    return DocumentProcessResponse(
        message="Document processing scheduled",
        document=service.build_detail_response(user, document),
    )


@router.post("/{document_id}/move", response_model=DocumentMoveResponse)
def move_document(
    document_id: UUID,
    payload: DocumentMoveRequest,
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = DocumentService(db)
    document = service.move_document(user, document_id, payload=payload)
    return service.build_move_response(user, document)


@router.post("/{document_id}/reindex", response_model=DocumentReindexResponse)
def reindex_document(
    document_id: UUID,
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    queued_documents = DocumentService(db).enqueue_document_reindex(user, document_id)
    return DocumentReindexResponse(
        message="Document reindex scheduled",
        queued_documents=queued_documents,
    )


@router.post("/{document_id}/review", response_model=DocumentReviewResponse)
def review_document(
    document_id: UUID,
    payload: DocumentReviewRequest,
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = DocumentService(db)
    document = service.submit_manual_review(user, document_id, payload=payload)
    return DocumentReviewResponse(
        message="Document manual review saved",
        document=service.build_detail_response(user, document),
    )


@router.put("/{document_id}/status", response_model=DocumentStatusUpdateResponse)
def update_document_status(
    document_id: UUID,
    payload: DocumentStatusUpdateRequest,
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = DocumentService(db)
    document = service.update_context_status(user, document_id, payload=payload)
    return DocumentStatusUpdateResponse(
        message="Document status updated",
        document=service.build_detail_response(user, document),
    )


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(
    document_id: UUID,
    _: Annotated[None, Depends(_require_cloud_document_storage)],
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    DocumentService(db).delete_document(user, document_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{document_id}/content")
def get_document_content(
    document_id: UUID,
    token: Annotated[str, Query(min_length=16)],
    db: Annotated[Session, Depends(get_db)],
):
    service = DocumentService(db)
    service.verify_view_token(document_id, token)
    document, content = service.get_document_content(document_id)
    return Response(
        content=content,
        media_type=document.mime_type,
        headers={
            "Content-Disposition": f'inline; filename="{document.original_filename}"',
        },
    )
