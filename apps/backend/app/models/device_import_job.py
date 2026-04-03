from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, utcnow


class DeviceImportJob(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "device_import_jobs"

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    connection_id: Mapped[str | None] = mapped_column(
        ForeignKey("device_connections.id", ondelete="SET NULL"),
        nullable=True,
    )
    provider_code: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending")
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    item_count: Mapped[int] = mapped_column(default=0, nullable=False)
    summary: Mapped[str | None] = mapped_column(Text)
    error_message: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="device_import_jobs")
    connection = relationship("DeviceConnection", back_populates="import_jobs")
