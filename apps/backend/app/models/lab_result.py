from __future__ import annotations

from sqlalchemy import Boolean, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class LabResult(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "lab_results"

    lab_panel_id: Mapped[str] = mapped_column(ForeignKey("lab_panels.id", ondelete="CASCADE"))
    analyte_name: Mapped[str] = mapped_column(String(255), nullable=False)
    value: Mapped[str] = mapped_column(String(255), nullable=False)
    unit: Mapped[str | None] = mapped_column(String(64))
    ref_min: Mapped[float | None] = mapped_column(Float)
    ref_max: Mapped[float | None] = mapped_column(Float)
    abnormal_flag: Mapped[bool | None] = mapped_column(Boolean)
    confidence_score: Mapped[float | None] = mapped_column(Float)

    lab_panel = relationship("LabPanel", back_populates="results")

