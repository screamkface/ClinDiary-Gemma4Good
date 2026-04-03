from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import (
    ClinicalDocumentType,
    DocumentContextStatus,
    DocumentParsedStatus,
    DocumentScanStatus,
)


class DocumentUploadResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    folder_id: UUID | None = None
    folder_name: str | None = None
    title: str
    document_type: ClinicalDocumentType
    upload_date: datetime
    exam_date: date | None
    source: str | None
    original_filename: str
    mime_type: str
    file_size_bytes: int
    content_sha256: str | None
    file_signature_valid: bool
    scan_status: DocumentScanStatus
    context_status: DocumentContextStatus
    scan_provider: str | None
    scan_error: str | None
    parsed_status: DocumentParsedStatus
    classification_confidence: float | None
    parsing_confidence: float | None
    processing_error: str | None


class LabResultResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    analyte_name: str
    value: str
    unit: str | None
    ref_min: float | None
    ref_max: float | None
    abnormal_flag: bool | None
    confidence_score: float | None


class LabPanelResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    panel_name: str
    panel_date: date | None
    confidence_score: float | None
    results: list[LabResultResponse]


class ImagingReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    exam_type: str | None
    body_part: str | None
    report_text: str
    impression: str | None
    confidence_score: float | None


class DocumentDetailResponse(DocumentUploadResponse):
    file_url: str
    ocr_text: str | None
    viewer_url: str | None = None
    processed_at: datetime | None
    lab_panels: list[LabPanelResponse]
    imaging_reports: list[ImagingReportResponse]


class DocumentFolderResponse(BaseModel):
    id: UUID
    name: str
    parent_folder_id: UUID | None = None
    path_label: str
    child_folder_count: int = 0
    document_count: int = 0


class DocumentArchiveResponse(BaseModel):
    current_folder: DocumentFolderResponse | None = None
    breadcrumbs: list[DocumentFolderResponse] = Field(default_factory=list)
    folders: list[DocumentFolderResponse] = Field(default_factory=list)
    documents: list[DocumentUploadResponse] = Field(default_factory=list)
    query: str | None = None
    is_search: bool = False


class DocumentProcessResponse(BaseModel):
    message: str
    document: DocumentDetailResponse


class LabResultReviewInput(BaseModel):
    analyte_name: str = Field(min_length=1, max_length=255)
    value: str = Field(min_length=1, max_length=255)
    unit: str | None = Field(default=None, max_length=64)
    ref_min: float | None = None
    ref_max: float | None = None
    abnormal_flag: bool | None = None


class LabPanelReviewInput(BaseModel):
    panel_name: str = Field(min_length=1, max_length=255)
    panel_date: date | None = None
    results: list[LabResultReviewInput] = Field(min_length=1)


class ImagingReportReviewInput(BaseModel):
    exam_type: str | None = Field(default=None, max_length=255)
    body_part: str | None = Field(default=None, max_length=255)
    report_text: str = Field(min_length=1)
    impression: str | None = None


class DocumentReviewRequest(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    document_type: ClinicalDocumentType | None = None
    exam_date: date | None = None
    source: str | None = Field(default=None, max_length=255)
    ocr_text: str | None = None
    lab_panel: LabPanelReviewInput | None = None
    imaging_report: ImagingReportReviewInput | None = None


class DocumentReviewResponse(BaseModel):
    message: str
    document: DocumentDetailResponse


class DocumentStatusUpdateRequest(BaseModel):
    context_status: DocumentContextStatus


class DocumentStatusUpdateResponse(BaseModel):
    message: str
    document: DocumentDetailResponse


class DocumentMoveRequest(BaseModel):
    folder_id: UUID | None = None


class DocumentMoveResponse(BaseModel):
    message: str
    document: DocumentDetailResponse


class DocumentReindexResponse(BaseModel):
    message: str
    queued_documents: int


class DocumentFolderCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    parent_folder_id: UUID | None = None


class DocumentQueryRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000)
    folder_id: UUID | None = None
    top_k: int | None = Field(default=None, ge=3, le=12)


class DocumentQueryCitationResponse(BaseModel):
    document_id: UUID
    document_title: str
    document_type: ClinicalDocumentType
    folder_name: str | None = None
    exam_date: date | None = None
    chunk_kind: str
    chunk_label: str | None = None
    excerpt: str
    score: float | None = None
    viewer_url: str | None = None


class DocumentQueryResponse(BaseModel):
    answer: str
    citations: list[DocumentQueryCitationResponse]
    provider_name: str
    model_name: str
    embedding_model_name: str | None = None
    reranker_model_name: str | None = None
    retrieved_chunks: int = 0
    retrieved_documents: int = 0
    search_scope_label: str = "Tutto l'archivio"
    coverage_note: str | None = None
    used_fallback: bool = False


class DocumentUploadForm(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    document_type: ClinicalDocumentType | None = None
    exam_date: date | None = None
    source: str | None = Field(default=None, max_length=255)
    folder_id: UUID | None = None
