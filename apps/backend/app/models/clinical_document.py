from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum, utcnow
from app.models.enums import (
    ClinicalDocumentType,
    DocumentContextStatus,
    DocumentParsedStatus,
    DocumentScanStatus,
)


class ClinicalDocument(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "clinical_documents"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    folder_id: Mapped[str | None] = mapped_column(
        ForeignKey("document_folders.id", ondelete="SET NULL")
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    document_type: Mapped[ClinicalDocumentType] = mapped_column(
        db_enum(ClinicalDocumentType, "clinical_document_type"),
        default=ClinicalDocumentType.GENERIC_DOCUMENT,
        nullable=False,
    )
    upload_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    exam_date: Mapped[date | None] = mapped_column(Date)
    source: Mapped[str | None] = mapped_column(String(255))
    file_url: Mapped[str] = mapped_column(String(512), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(128), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    content_sha256: Mapped[str | None] = mapped_column(String(64))
    file_signature_valid: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    scan_status: Mapped[DocumentScanStatus] = mapped_column(
        db_enum(DocumentScanStatus, "document_scan_status"),
        default=DocumentScanStatus.SKIPPED,
        nullable=False,
    )
    context_status: Mapped[DocumentContextStatus] = mapped_column(
        db_enum(DocumentContextStatus, "document_context_status"),
        default=DocumentContextStatus.ACTIVE,
        nullable=False,
    )
    scan_provider: Mapped[str | None] = mapped_column(String(64))
    scan_error: Mapped[str | None] = mapped_column(Text)
    ocr_text: Mapped[str | None] = mapped_column(Text)
    parsed_status: Mapped[DocumentParsedStatus] = mapped_column(
        db_enum(DocumentParsedStatus, "document_parsed_status"),
        default=DocumentParsedStatus.PENDING,
        nullable=False,
    )
    classification_confidence: Mapped[float | None] = mapped_column(Float)
    parsing_confidence: Mapped[float | None] = mapped_column(Float)
    processing_error: Mapped[str | None] = mapped_column(Text)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    patient = relationship("PatientProfile", back_populates="clinical_documents")
    folder = relationship("DocumentFolder", back_populates="documents")
    lab_panels = relationship(
        "LabPanel",
        back_populates="document",
        cascade="all, delete-orphan",
    )
    imaging_reports = relationship(
        "ImagingReport",
        back_populates="document",
        cascade="all, delete-orphan",
    )
    chunks = relationship(
        "DocumentChunk",
        back_populates="document",
        cascade="all, delete-orphan",
    )

    @property
    def folder_name(self) -> str | None:
        return self.folder.name if self.folder is not None else None
