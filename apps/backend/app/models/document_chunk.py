from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum, utcnow
from app.models.enums import ClinicalDocumentType, DocumentContextStatus
from app.models.vector_type import VectorListType


class DocumentChunk(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "document_chunks"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    document_id: Mapped[str] = mapped_column(ForeignKey("clinical_documents.id", ondelete="CASCADE"))
    folder_id: Mapped[str | None] = mapped_column(ForeignKey("document_folders.id", ondelete="SET NULL"))
    document_title: Mapped[str] = mapped_column(String(255), nullable=False)
    folder_name: Mapped[str | None] = mapped_column(String(255))
    document_type: Mapped[ClinicalDocumentType] = mapped_column(
        db_enum(ClinicalDocumentType, "clinical_document_type"),
        nullable=False,
    )
    context_status: Mapped[DocumentContextStatus] = mapped_column(
        db_enum(DocumentContextStatus, "document_context_status"),
        nullable=False,
    )
    source: Mapped[str | None] = mapped_column(String(255))
    upload_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    exam_date: Mapped[date | None] = mapped_column(Date)
    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    chunk_kind: Mapped[str] = mapped_column(String(64), nullable=False)
    chunk_label: Mapped[str | None] = mapped_column(String(255))
    content: Mapped[str] = mapped_column(Text, nullable=False)
    embedding_model_name: Mapped[str | None] = mapped_column(String(128))
    embedding_dimensions: Mapped[int | None] = mapped_column(Integer)
    embedding: Mapped[list[float] | None] = mapped_column(VectorListType())
    embedded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    patient = relationship("PatientProfile", back_populates="document_chunks")
    document = relationship("ClinicalDocument", back_populates="chunks")
    folder = relationship("DocumentFolder")
