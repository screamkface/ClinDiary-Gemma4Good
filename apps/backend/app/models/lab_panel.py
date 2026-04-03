from __future__ import annotations

from datetime import date

from sqlalchemy import Date, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class LabPanel(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "lab_panels"

    document_id: Mapped[str] = mapped_column(ForeignKey("clinical_documents.id", ondelete="CASCADE"))
    panel_name: Mapped[str] = mapped_column(String(255), nullable=False)
    panel_date: Mapped[date | None] = mapped_column(Date)
    confidence_score: Mapped[float | None] = mapped_column(Float)

    document = relationship("ClinicalDocument", back_populates="lab_panels")
    results = relationship(
        "LabResult",
        back_populates="lab_panel",
        cascade="all, delete-orphan",
    )

