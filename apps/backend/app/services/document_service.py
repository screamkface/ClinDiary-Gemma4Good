from __future__ import annotations

from hashlib import sha256
from io import BytesIO
from pathlib import PurePosixPath
from uuid import UUID, uuid4

from fastapi import HTTPException, UploadFile, status
from pypdf import PdfReader
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import create_document_view_token, decode_token, utcnow
from app.core.storage import get_storage_service
from app.models.clinical_document import ClinicalDocument
from app.models.document_folder import DocumentFolder
from app.models.enums import (
    ClinicalDocumentType,
    DocumentContextStatus,
    DocumentParsedStatus,
    DocumentScanStatus,
    NotificationType,
    TimelineEventType,
)
from app.models.imaging_report import ImagingReport
from app.models.lab_panel import LabPanel
from app.models.lab_result import LabResult
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.repositories.document_repository import DocumentRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.timeline_repository import TimelineRepository
from app.services.profile_context import resolve_user_profile
from app.schemas.documents import (
    DocumentArchiveResponse,
    DocumentDetailResponse,
    DocumentFolderCreateRequest,
    DocumentFolderResponse,
    DocumentMoveRequest,
    DocumentReviewRequest,
    DocumentMoveResponse,
    DocumentStatusUpdateRequest,
    DocumentUploadForm,
    DocumentUploadResponse,
    ImagingReportReviewInput,
    LabPanelReviewInput,
)
from app.services.document_classifier import DocumentClassifier
from app.services.audit_service import AuditService
from app.services.ocr_service import get_ocr_service
from app.services.document_scan_service import DocumentScanService
from app.services.document_parser import DocumentParser


ALLOWED_DOCUMENT_MIME_TYPES = {"application/pdf", "image/jpeg", "image/png"}
settings = get_settings()


class DocumentService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.document_repository = DocumentRepository(db)
        self.notification_repository = NotificationRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.storage_service = get_storage_service()
        self.classifier = DocumentClassifier()
        self.parser = DocumentParser()
        self.ocr_service = get_ocr_service()
        self.scan_service = DocumentScanService()
        self.audit_service = AuditService(db)

    def upload_document(self, user: User, *, payload: DocumentUploadForm, file: UploadFile) -> ClinicalDocument:
        profile = self._require_profile(user)
        target_folder = (
            self._get_folder_for_patient(profile.id, payload.folder_id)
            if payload.folder_id is not None
            else None
        )
        content = file.file.read()
        file.file.close()

        if file.content_type not in ALLOWED_DOCUMENT_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail="Unsupported document type",
            )

        max_size_bytes = settings.document_max_size_mb * 1024 * 1024
        if len(content) > max_size_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Document exceeds maximum size",
            )

        if settings.document_magic_bytes_validation and not self._has_expected_signature(
            content,
            file.content_type or "",
        ):
            self.audit_service.log_for_user(
                user,
                event_type="document_upload_rejected",
                entity_type="clinical_document",
                summary="Upload documento bloccato per firma file non coerente con il MIME.",
                outcome="blocked",
                metadata={
                    "mime_type": file.content_type,
                    "filename": file.filename,
                },
            )
            self.db.commit()
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail="File signature does not match the declared document type",
            )

        content_sha256 = sha256(content).hexdigest()
        scan_result = self.scan_service.scan(
            filename=file.filename or "document",
            content=content,
            mime_type=file.content_type or "",
            sha256_hash=content_sha256,
        )
        if scan_result.status == "failed" and settings.document_scan_fail_closed:
            self.audit_service.log_for_user(
                user,
                event_type="document_upload_rejected",
                entity_type="clinical_document",
                summary="Upload documento bloccato dal controllo di sicurezza.",
                outcome="blocked",
                metadata={
                    "mime_type": file.content_type,
                    "filename": file.filename,
                    "scan_provider": scan_result.provider,
                    "scan_error": scan_result.error,
                },
            )
            self.db.commit()
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=scan_result.error or "Document failed the configured security scan",
            )

        original_filename = file.filename or f"document-{uuid4()}"
        object_key = self._build_object_key(profile.id, original_filename)
        stored = self.storage_service.save_bytes(
            object_key=object_key,
            data=content,
            content_type=file.content_type,
        )

        document = ClinicalDocument(
            patient_id=profile.id,
            folder_id=target_folder.id if target_folder is not None else None,
            title=payload.title or PurePosixPath(original_filename).stem,
            document_type=payload.document_type or ClinicalDocumentType.GENERIC_DOCUMENT,
            exam_date=payload.exam_date,
            source=payload.source,
            file_url=stored.object_key,
            original_filename=original_filename,
            mime_type=file.content_type,
            file_size_bytes=stored.size_bytes,
            content_sha256=content_sha256,
            file_signature_valid=True,
            scan_status=DocumentScanStatus(scan_result.status),
            scan_provider=scan_result.provider,
            scan_error=scan_result.error,
            parsed_status=DocumentParsedStatus.PENDING,
        )
        self.document_repository.add(document)
        self.db.flush()

        self.timeline_repository.upsert_source_event(
            patient_id=profile.id,
            source_type="clinical_document",
            source_id=document.id,
            event_type=TimelineEventType.DOCUMENT_UPLOADED,
            title=f"Documento caricato: {document.title}",
            description=f"Caricato {document.document_type.value} da {document.original_filename}.",
            event_date=document.upload_date,
        )
        self.audit_service.log_for_user(
            user,
            event_type="document_uploaded",
            entity_type="clinical_document",
            entity_id=document.id,
            summary=f"Documento caricato: {document.title}",
            metadata={
                "mime_type": document.mime_type,
                "folder_id": str(document.folder_id) if document.folder_id else None,
                "scan_status": document.scan_status.value,
                "scan_provider": document.scan_provider,
            },
        )
        self.db.commit()
        self._schedule_document_reindex(document.id)
        return self._get_document_for_patient(profile.id, document.id)

    def list_documents(self, user: User) -> list[ClinicalDocument]:
        profile = self._require_profile(user)
        return self.document_repository.list_for_patient(profile.id)

    def list_archive(
        self,
        user: User,
        *,
        folder_id: UUID | None = None,
        query: str | None = None,
    ) -> DocumentArchiveResponse:
        profile = self._require_profile(user)
        normalized_query = self._normalize_optional_text(query)
        current_folder = (
            self._get_folder_for_patient(profile.id, folder_id) if folder_id is not None else None
        )
        all_folders = self.document_repository.list_all_folders_for_patient(profile.id)
        folder_map = {folder.id: folder for folder in all_folders}
        direct_child_counts: dict[UUID | None, int] = {}
        for folder in all_folders:
            direct_child_counts[folder.parent_folder_id] = direct_child_counts.get(folder.parent_folder_id, 0) + 1

        documents_for_counts = self.document_repository.list_for_patient_with_details(profile.id)
        document_counts: dict[UUID | None, int] = {}
        for document in documents_for_counts:
            document_counts[document.folder_id] = document_counts.get(document.folder_id, 0) + 1

        if normalized_query:
            folders = []
            documents = self.document_repository.search_for_patient(profile.id, normalized_query)
        else:
            folders = self.document_repository.list_folders_for_patient(
                profile.id,
                parent_folder_id=current_folder.id if current_folder is not None else None,
            )
            documents = self.document_repository.list_for_patient(
                profile.id,
                folder_id=current_folder.id if current_folder is not None else None,
                root_only=current_folder is None,
            )

        breadcrumbs = self._build_folder_breadcrumbs(current_folder, folder_map)
        return DocumentArchiveResponse(
            current_folder=(
                self._build_folder_response(current_folder, folder_map, direct_child_counts, document_counts)
                if current_folder is not None
                else None
            ),
            breadcrumbs=[
                self._build_folder_response(folder, folder_map, direct_child_counts, document_counts)
                for folder in breadcrumbs
            ],
            folders=[
                self._build_folder_response(folder, folder_map, direct_child_counts, document_counts)
                for folder in folders
            ],
            documents=[DocumentUploadResponse.model_validate(document) for document in documents],
            query=normalized_query,
            is_search=normalized_query is not None,
        )

    def list_folders(self, user: User) -> list[DocumentFolderResponse]:
        profile = self._require_profile(user)
        folders = self.document_repository.list_all_folders_for_patient(profile.id)
        folder_map = {folder.id: folder for folder in folders}
        direct_child_counts: dict[UUID | None, int] = {}
        for folder in folders:
            direct_child_counts[folder.parent_folder_id] = direct_child_counts.get(folder.parent_folder_id, 0) + 1
        documents = self.document_repository.list_for_patient_with_details(profile.id)
        document_counts: dict[UUID | None, int] = {}
        for document in documents:
            document_counts[document.folder_id] = document_counts.get(document.folder_id, 0) + 1
        return [
            self._build_folder_response(folder, folder_map, direct_child_counts, document_counts)
            for folder in folders
        ]

    def create_folder(
        self,
        user: User,
        *,
        payload: DocumentFolderCreateRequest,
    ) -> DocumentFolderResponse:
        profile = self._require_profile(user)
        parent_folder = (
            self._get_folder_for_patient(profile.id, payload.parent_folder_id)
            if payload.parent_folder_id is not None
            else None
        )
        normalized_name = payload.name.strip()
        siblings = self.document_repository.list_folders_for_patient(
            profile.id,
            parent_folder_id=parent_folder.id if parent_folder is not None else None,
        )
        if any(folder.name.lower() == normalized_name.lower() for folder in siblings):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A folder with this name already exists in the selected path",
            )
        folder = DocumentFolder(
            patient_id=profile.id,
            parent_folder_id=parent_folder.id if parent_folder is not None else None,
            name=normalized_name,
        )
        self.document_repository.add_folder(folder)
        self.db.flush()
        self.audit_service.log_for_user(
            user,
            event_type="document_folder_created",
            entity_type="document_folder",
            entity_id=folder.id,
            summary=f"Cartella documenti creata: {folder.name}",
            metadata={"parent_folder_id": str(folder.parent_folder_id) if folder.parent_folder_id else None},
        )
        self.db.commit()
        folders = self.document_repository.list_all_folders_for_patient(profile.id)
        folder_map = {item.id: item for item in folders}
        direct_child_counts: dict[UUID | None, int] = {}
        for item in folders:
            direct_child_counts[item.parent_folder_id] = direct_child_counts.get(item.parent_folder_id, 0) + 1
        documents = self.document_repository.list_for_patient_with_details(profile.id)
        document_counts: dict[UUID | None, int] = {}
        for document in documents:
            document_counts[document.folder_id] = document_counts.get(document.folder_id, 0) + 1
        return self._build_folder_response(folder_map[folder.id], folder_map, direct_child_counts, document_counts)

    def move_document(
        self,
        user: User,
        document_id: UUID,
        *,
        payload: DocumentMoveRequest,
    ) -> ClinicalDocument:
        document = self.get_document(user, document_id)
        target_folder = (
            self._get_folder_for_patient(document.patient_id, payload.folder_id)
            if payload.folder_id is not None
            else None
        )
        document.folder_id = target_folder.id if target_folder is not None else None
        self.audit_service.log_for_user(
            user,
            event_type="document_moved",
            entity_type="clinical_document",
            entity_id=document.id,
            summary=f"Documento spostato: {document.title}",
            metadata={"folder_id": str(document.folder_id) if document.folder_id else None},
        )
        self.db.commit()
        self._schedule_document_reindex(document.id)
        return self.get_document(user, document.id)

    def get_document(self, user: User, document_id: UUID) -> ClinicalDocument:
        profile = self._require_profile(user)
        return self._get_document_for_patient(profile.id, document_id)

    def update_context_status(
        self,
        user: User,
        document_id: UUID,
        *,
        payload: DocumentStatusUpdateRequest,
    ) -> ClinicalDocument:
        document = self.get_document(user, document_id)
        document.context_status = payload.context_status
        self._deactivate_document_follow_up_notification(
            patient_id=document.patient_id,
            document_id=document.id,
        )
        self.audit_service.log_for_user(
            user,
            event_type="document_context_status_updated",
            entity_type="clinical_document",
            entity_id=document.id,
            summary=f"Documento aggiornato a stato {document.context_status.value}: {document.title}",
            metadata={"context_status": document.context_status.value},
        )
        self.db.commit()
        self._schedule_document_reindex(document.id)
        self.db.refresh(document)
        return self.get_document(user, document.id)

    def delete_document(self, user: User, document_id: UUID) -> None:
        document = self.get_document(user, document_id)
        from app.services.document_rag_service import DocumentRagService

        DocumentRagService(self.db).delete_document_index(document.id)
        self.storage_service.delete_bytes(document.file_url)
        self._remove_summary_events(document.id)
        self.timeline_repository.delete_by_source("clinical_document", document.id)
        self._deactivate_document_follow_up_notification(
            patient_id=document.patient_id,
            document_id=document.id,
        )
        self.audit_service.log_for_user(
            user,
            event_type="document_deleted",
            entity_type="clinical_document",
            entity_id=document.id,
            summary=f"Documento eliminato: {document.title}",
            metadata={"context_status": document.context_status.value},
        )
        self.document_repository.delete(document)
        self.db.commit()

    def enqueue_processing(self, user: User, document_id: UUID) -> ClinicalDocument:
        document = self.get_document(user, document_id)
        document.parsed_status = DocumentParsedStatus.PROCESSING
        document.processing_error = None
        self.audit_service.log_for_user(
            user,
            event_type="document_processing_enqueued",
            entity_type="clinical_document",
            entity_id=document.id,
            summary=f"Processing documento avviato per {document.title}",
        )
        self.db.commit()

        from app.workers.document_tasks import process_document_task

        process_document_task.delay(str(document.id))
        self.db.expire_all()
        return self.get_document(user, document.id)

    def submit_manual_review(
        self,
        user: User,
        document_id: UUID,
        *,
        payload: DocumentReviewRequest,
    ) -> ClinicalDocument:
        document = self.get_document(user, document_id)
        title = self._normalize_optional_text(payload.title) or document.title
        reviewed_text = self._normalize_optional_text(payload.ocr_text)
        target_type = payload.document_type or document.document_type

        existing_lab_panel = self._snapshot_existing_lab_panel(document)
        existing_imaging_report = self._snapshot_existing_imaging_report(document)

        document.title = title
        if payload.document_type is not None:
            document.document_type = payload.document_type
        if payload.exam_date is not None:
            document.exam_date = payload.exam_date
        if payload.source is not None:
            document.source = self._normalize_optional_text(payload.source)
        if payload.ocr_text is not None:
            document.ocr_text = reviewed_text

        self.document_repository.clear_structured_data(document)
        self._remove_summary_events(document.id)

        if target_type == ClinicalDocumentType.LAB_REPORT:
            lab_panel = self._resolve_review_lab_panel(
                document=document,
                title=title,
                reviewed_text=reviewed_text,
                payload_panel=payload.lab_panel,
                existing_panel=existing_lab_panel,
            )
            self._append_manual_lab_panel(document, lab_panel)
            document.parsed_status = DocumentParsedStatus.REVIEWED
            document.classification_confidence = 1.0
            document.parsing_confidence = 1.0
            document.processing_error = None
            self.timeline_repository.upsert_source_event(
                patient_id=document.patient_id,
                source_type="clinical_document_lab_summary",
                source_id=document.id,
                event_type=TimelineEventType.LAB_RESULT_SUMMARY,
                title="Referto laboratorio revisionato",
                description=f"Revisione manuale completata per {document.title}.",
                event_date=utcnow(),
            )
        elif target_type == ClinicalDocumentType.IMAGING_REPORT:
            imaging_report = self._resolve_review_imaging_report(
                document=document,
                title=title,
                reviewed_text=reviewed_text,
                payload_report=payload.imaging_report,
                existing_report=existing_imaging_report,
            )
            self._append_manual_imaging_report(document, imaging_report)
            document.parsed_status = DocumentParsedStatus.REVIEWED
            document.classification_confidence = 1.0
            document.parsing_confidence = 1.0
            document.processing_error = None
            self.timeline_repository.upsert_source_event(
                patient_id=document.patient_id,
                source_type="clinical_document_imaging_summary",
                source_id=document.id,
                event_type=TimelineEventType.IMAGING_SUMMARY,
                title="Referto imaging revisionato",
                description=f"Revisione manuale completata per {document.title}.",
                event_date=utcnow(),
            )
        else:
            document.parsed_status = DocumentParsedStatus.REVIEWED
            document.classification_confidence = 1.0
            document.parsing_confidence = 1.0 if document.ocr_text else None
            document.processing_error = None

        document.processed_at = utcnow()
        self.audit_service.log_for_user(
            user,
            event_type="document_reviewed",
            entity_type="clinical_document",
            entity_id=document.id,
            summary=f"Revisione manuale salvata per {document.title}",
            metadata={
                "document_type": document.document_type.value,
                "parsed_status": document.parsed_status.value,
            },
        )
        self.db.commit()
        self._schedule_document_reindex(document.id)
        return self.get_document(user, document.id)

    def process_document(self, document_id: UUID) -> ClinicalDocument:
        document = self.document_repository.get_by_id(document_id)
        if document is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

        self.document_repository.clear_structured_data(document)
        document.parsed_status = DocumentParsedStatus.PROCESSING
        document.processing_error = None
        document.ocr_text = None
        document.parsing_confidence = None
        document.classification_confidence = None
        self.db.flush()

        try:
            content = self.storage_service.read_bytes(document.file_url)
            extracted_text, extraction_error = self._extract_text(document, content)
            document.ocr_text = extracted_text

            classification = self.classifier.classify(document, extracted_text)
            document.document_type = classification.document_type
            document.classification_confidence = classification.confidence

            if extracted_text is None:
                document.parsed_status = DocumentParsedStatus.OCR_PENDING
                document.processing_error = (
                    extraction_error
                    or "OCR completo non disponibile: nessun testo estratto dal documento."
                )
                self._remove_summary_events(document.id)
            else:
                self._parse_structured_content(document, extracted_text)

            document.processed_at = utcnow()
            self.audit_service.log_event(
                patient_id=document.patient_id,
                event_type="document_processed",
                entity_type="clinical_document",
                entity_id=document.id,
                summary=f"Processing completato per {document.title}",
                metadata={
                    "parsed_status": document.parsed_status.value,
                    "document_type": document.document_type.value,
                    "scan_status": document.scan_status.value,
                },
            )
            from app.services.document_rag_service import DocumentRagService

            try:
                DocumentRagService(self.db).reindex_document(document.id)
            except Exception as exc:
                logger.warning(
                    "documents.reindex_failed_after_processing",
                    document_id=str(document.id),
                    error=str(exc),
                )
            self.db.commit()
        except Exception as exc:
            document.parsed_status = DocumentParsedStatus.FAILED
            document.processing_error = str(exc)
            document.processed_at = utcnow()
            self.audit_service.log_event(
                patient_id=document.patient_id,
                event_type="document_processing_failed",
                entity_type="clinical_document",
                entity_id=document.id,
                summary=f"Processing fallito per {document.title}",
                outcome="failure",
                metadata={"error": str(exc)},
            )
            self.db.commit()
            raise

        return self.document_repository.get_by_id(document.id) or document

    def enqueue_document_reindex(self, user: User, document_id: UUID) -> int:
        document = self.get_document(user, document_id)
        self._schedule_document_reindex(document.id)
        return 1

    def enqueue_patient_reindex(self, user: User) -> int:
        profile = self._require_profile(user)
        documents = self.document_repository.list_for_patient(profile.id)
        from app.workers.document_tasks import reindex_patient_documents_task

        reindex_patient_documents_task.delay(str(profile.id))
        return len(documents)

    def build_detail_response(self, user: User, document: ClinicalDocument) -> DocumentDetailResponse:
        viewer_token, _ = create_document_view_token(document_id=document.id, user_id=user.id)
        payload = DocumentDetailResponse.model_validate(document)
        return payload.model_copy(
            update={"viewer_url": f"{settings.api_v1_prefix}/documents/{document.id}/content?token={viewer_token}"}
        )

    def verify_view_token(self, document_id: UUID, token: str) -> None:
        try:
            payload = decode_token(token)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid viewer token") from exc

        if payload.get("type") != "document_view" or payload.get("document_id") != str(document_id):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid viewer token")

    def get_document_content(self, document_id: UUID) -> tuple[ClinicalDocument, bytes]:
        document = self.document_repository.get_by_id(document_id)
        if document is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
        return document, self.storage_service.read_bytes(document.file_url)

    def build_move_response(self, user: User, document: ClinicalDocument) -> DocumentMoveResponse:
        return DocumentMoveResponse(
            message="Document moved",
            document=self.build_detail_response(user, document),
        )

    def _parse_structured_content(self, document: ClinicalDocument, extracted_text: str) -> None:
        if document.document_type == ClinicalDocumentType.LAB_REPORT:
            panel = self.parser.parse_lab_text(document.title, extracted_text)
            if panel is None:
                document.parsed_status = DocumentParsedStatus.REVIEW_REQUIRED
                document.processing_error = "Laboratory report recognized but no structured values extracted."
                self._remove_summary_events(document.id)
                return

            panel_model = LabPanel(
                document_id=document.id,
                panel_name=panel.panel_name,
                panel_date=panel.panel_date or document.exam_date,
                confidence_score=panel.confidence_score,
            )
            document.lab_panels.append(panel_model)
            for result in panel.results:
                panel_model.results.append(
                    LabResult(
                        analyte_name=result.analyte_name,
                        value=result.value,
                        unit=result.unit,
                        ref_min=result.ref_min,
                        ref_max=result.ref_max,
                        abnormal_flag=result.abnormal_flag,
                        confidence_score=result.confidence_score,
                    )
                )
            document.parsed_status = DocumentParsedStatus.PARSED
            document.parsing_confidence = panel.confidence_score
            document.processing_error = None
            self.timeline_repository.upsert_source_event(
                patient_id=document.patient_id,
                source_type="clinical_document_lab_summary",
                source_id=document.id,
                event_type=TimelineEventType.LAB_RESULT_SUMMARY,
                title="Referto laboratorio processato",
                description=f"Estratti {len(panel.results)} risultati strutturati da {document.title}.",
                event_date=utcnow(),
            )
            self.timeline_repository.delete_by_source("clinical_document_imaging_summary", document.id)
            return

        if document.document_type == ClinicalDocumentType.IMAGING_REPORT:
            parsed = self.parser.parse_imaging_text(document.title, extracted_text)
            if parsed is None:
                document.parsed_status = DocumentParsedStatus.REVIEW_REQUIRED
                document.processing_error = "Imaging report recognized but no report content extracted."
                self._remove_summary_events(document.id)
                return

            document.imaging_reports.append(
                ImagingReport(
                    document_id=document.id,
                    exam_type=parsed.exam_type,
                    body_part=parsed.body_part,
                    report_text=parsed.report_text,
                    impression=parsed.impression,
                    confidence_score=parsed.confidence_score,
                )
            )
            document.parsed_status = DocumentParsedStatus.PARSED
            document.parsing_confidence = parsed.confidence_score
            document.processing_error = None
            self.timeline_repository.upsert_source_event(
                patient_id=document.patient_id,
                source_type="clinical_document_imaging_summary",
                source_id=document.id,
                event_type=TimelineEventType.IMAGING_SUMMARY,
                title="Referto imaging processato",
                description=f"Imaging {parsed.exam_type or document.title} disponibile in timeline.",
                event_date=utcnow(),
            )
            self.timeline_repository.delete_by_source("clinical_document_lab_summary", document.id)
            return

        document.parsed_status = DocumentParsedStatus.PARSED
        document.parsing_confidence = 0.65 if extracted_text.strip() else None
        document.processing_error = None
        self._remove_summary_events(document.id)

    def _remove_summary_events(self, document_id: UUID) -> None:
        self.timeline_repository.delete_by_source("clinical_document_lab_summary", document_id)
        self.timeline_repository.delete_by_source("clinical_document_imaging_summary", document_id)

    def _deactivate_document_follow_up_notification(self, *, patient_id: UUID, document_id: UUID) -> None:
        notification = self.notification_repository.get_by_dedupe(
            patient_id,
            f"document-follow-up-{document_id}",
        )
        if notification is not None and notification.notification_type == NotificationType.DOCUMENT_FOLLOW_UP:
            notification.is_active = False

    def _resolve_review_lab_panel(
        self,
        *,
        document: ClinicalDocument,
        title: str,
        reviewed_text: str | None,
        payload_panel: LabPanelReviewInput | None,
        existing_panel: LabPanelReviewInput | None,
    ) -> LabPanelReviewInput:
        if payload_panel is not None:
            return payload_panel

        candidate_text = reviewed_text if reviewed_text is not None else document.ocr_text
        if candidate_text:
            parsed = self.parser.parse_lab_text(title, candidate_text)
            if parsed is not None:
                return LabPanelReviewInput(
                    panel_name=parsed.panel_name,
                    panel_date=parsed.panel_date or document.exam_date,
                    results=[
                        {
                            "analyte_name": result.analyte_name,
                            "value": result.value,
                            "unit": result.unit,
                            "ref_min": result.ref_min,
                            "ref_max": result.ref_max,
                            "abnormal_flag": result.abnormal_flag,
                        }
                        for result in parsed.results
                    ],
                )

        if existing_panel is not None:
            return existing_panel

        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Manual review for lab reports requires structured results or corrected text.",
        )

    def _resolve_review_imaging_report(
        self,
        *,
        document: ClinicalDocument,
        title: str,
        reviewed_text: str | None,
        payload_report: ImagingReportReviewInput | None,
        existing_report: ImagingReportReviewInput | None,
    ) -> ImagingReportReviewInput:
        if payload_report is not None:
            return payload_report

        candidate_text = reviewed_text if reviewed_text is not None else document.ocr_text
        if candidate_text:
            parsed = self.parser.parse_imaging_text(title, candidate_text)
            if parsed is not None:
                return ImagingReportReviewInput(
                    exam_type=parsed.exam_type,
                    body_part=parsed.body_part,
                    report_text=parsed.report_text,
                    impression=parsed.impression,
                )

        if existing_report is not None:
            return existing_report

        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Manual review for imaging reports requires a report body or corrected text.",
        )

    def _append_manual_lab_panel(
        self,
        document: ClinicalDocument,
        panel_input: LabPanelReviewInput,
    ) -> None:
        panel_model = LabPanel(
            document_id=document.id,
            panel_name=panel_input.panel_name,
            panel_date=panel_input.panel_date or document.exam_date,
            confidence_score=1.0,
        )
        document.lab_panels.append(panel_model)
        for result in panel_input.results:
            abnormal_flag = result.abnormal_flag
            if abnormal_flag is None and result.ref_min is not None and result.ref_max is not None:
                try:
                    numeric_value = float(str(result.value).replace(",", "."))
                except ValueError:
                    numeric_value = None
                if numeric_value is not None:
                    abnormal_flag = numeric_value < result.ref_min or numeric_value > result.ref_max
            panel_model.results.append(
                LabResult(
                    analyte_name=result.analyte_name,
                    value=result.value,
                    unit=result.unit,
                    ref_min=result.ref_min,
                    ref_max=result.ref_max,
                    abnormal_flag=abnormal_flag,
                    confidence_score=1.0,
                )
            )

    def _append_manual_imaging_report(
        self,
        document: ClinicalDocument,
        report_input: ImagingReportReviewInput,
    ) -> None:
        document.imaging_reports.append(
            ImagingReport(
                document_id=document.id,
                exam_type=report_input.exam_type,
                body_part=report_input.body_part,
                report_text=report_input.report_text,
                impression=report_input.impression,
                confidence_score=1.0,
            )
        )

    def _extract_text(self, document: ClinicalDocument, content: bytes) -> tuple[str | None, str | None]:
        if document.mime_type == "application/pdf":
            reader = PdfReader(BytesIO(content))
            pdf_text = "\n".join((page.extract_text() or "") for page in reader.pages).strip()
            if pdf_text:
                return pdf_text, None

        if document.mime_type not in ALLOWED_DOCUMENT_MIME_TYPES:
            return None, "OCR completo non disponibile: formato file non supportato."

        ocr_result = self.ocr_service.extract_text(
            content=content,
            mime_type=document.mime_type or "",
            filename_hint=document.original_filename,
        )
        return ocr_result.text, ocr_result.error

    @staticmethod
    def _has_expected_signature(content: bytes, mime_type: str) -> bool:
        if not content:
            return False
        if mime_type == "application/pdf":
            return content.startswith(b"%PDF-")
        if mime_type == "image/jpeg":
            return content.startswith(b"\xff\xd8\xff")
        if mime_type == "image/png":
            return content.startswith(b"\x89PNG\r\n\x1a\n")
        return False

    def _require_profile(self, user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    def _get_document_for_patient(self, patient_id: UUID, document_id: UUID) -> ClinicalDocument:
        document = self.document_repository.get_for_patient(patient_id, document_id)
        if document is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
        return document

    def _get_folder_for_patient(self, patient_id: UUID, folder_id: UUID) -> DocumentFolder:
        folder = self.document_repository.get_folder_for_patient(patient_id, folder_id)
        if folder is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found")
        return folder

    def _build_folder_breadcrumbs(
        self,
        current_folder: DocumentFolder | None,
        folder_map: dict[UUID, DocumentFolder],
    ) -> list[DocumentFolder]:
        if current_folder is None:
            return []
        items: list[DocumentFolder] = []
        cursor: DocumentFolder | None = current_folder
        while cursor is not None:
            items.append(cursor)
            cursor = folder_map.get(cursor.parent_folder_id) if cursor.parent_folder_id else None
        return list(reversed(items))

    def _build_folder_path_label(
        self,
        folder: DocumentFolder,
        folder_map: dict[UUID, DocumentFolder],
    ) -> str:
        parts = [item.name for item in self._build_folder_breadcrumbs(folder, folder_map)]
        return " / ".join(parts)

    def _build_folder_response(
        self,
        folder: DocumentFolder,
        folder_map: dict[UUID, DocumentFolder],
        direct_child_counts: dict[UUID | None, int],
        document_counts: dict[UUID | None, int],
    ) -> DocumentFolderResponse:
        return DocumentFolderResponse(
            id=folder.id,
            name=folder.name,
            parent_folder_id=folder.parent_folder_id,
            path_label=self._build_folder_path_label(folder, folder_map),
            child_folder_count=direct_child_counts.get(folder.id, 0),
            document_count=document_counts.get(folder.id, 0),
        )

    @staticmethod
    def _normalize_optional_text(value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @staticmethod
    def _snapshot_existing_lab_panel(document: ClinicalDocument) -> LabPanelReviewInput | None:
        if not document.lab_panels:
            return None
        panel = document.lab_panels[0]
        return LabPanelReviewInput(
            panel_name=panel.panel_name,
            panel_date=panel.panel_date,
            results=[
                {
                    "analyte_name": result.analyte_name,
                    "value": result.value,
                    "unit": result.unit,
                    "ref_min": result.ref_min,
                    "ref_max": result.ref_max,
                    "abnormal_flag": result.abnormal_flag,
                }
                for result in panel.results
            ],
        )

    @staticmethod
    def _snapshot_existing_imaging_report(document: ClinicalDocument) -> ImagingReportReviewInput | None:
        if not document.imaging_reports:
            return None
        report = document.imaging_reports[0]
        return ImagingReportReviewInput(
            exam_type=report.exam_type,
            body_part=report.body_part,
            report_text=report.report_text,
            impression=report.impression,
        )

    @staticmethod
    def _build_object_key(patient_id: UUID, original_filename: str) -> str:
        suffix = PurePosixPath(original_filename).suffix
        return f"patients/{patient_id}/documents/{uuid4()}{suffix}"

    @staticmethod
    def _schedule_document_reindex(document_id: UUID) -> None:
        from app.workers.document_tasks import reindex_document_task

        reindex_document_task.delay(str(document_id))
