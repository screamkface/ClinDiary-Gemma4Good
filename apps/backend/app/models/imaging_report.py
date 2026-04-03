from __future__ import annotations

from sqlalchemy import Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class ImagingReport(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "imaging_reports"

    document_id: Mapped[str] = mapped_column(ForeignKey("clinical_documents.id", ondelete="CASCADE"))
    exam_type: Mapped[str | None] = mapped_column(String(255))
    body_part: Mapped[str | None] = mapped_column(String(255))
    report_text: Mapped[str] = mapped_column(Text, nullable=False)
    impression: Mapped[str | None] = mapped_column(Text)
    confidence_score: Mapped[float | None] = mapped_column(Float)

    document = relationship("ClinicalDocument", back_populates="imaging_reports")
