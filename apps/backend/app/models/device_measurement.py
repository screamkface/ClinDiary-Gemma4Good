from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class DeviceMeasurement(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "device_measurements"
    __table_args__ = (
        Index("ix_device_measurements_patient_measured_at", "patient_id", "measured_at"),
        Index("ix_device_measurements_connection_id", "connection_id"),
        Index("ix_device_measurements_metric_type", "metric_type"),
    )

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    connection_id: Mapped[str | None] = mapped_column(
        ForeignKey("device_connections.id", ondelete="SET NULL"),
        nullable=True,
    )
    provider_code: Mapped[str] = mapped_column(String(64), nullable=False)
    metric_type: Mapped[str] = mapped_column(String(64), nullable=False)
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source_record_id: Mapped[str | None] = mapped_column(String(255))
    source_device_model: Mapped[str | None] = mapped_column(String(255))
    unit: Mapped[str | None] = mapped_column(String(64))
    primary_value: Mapped[float | None]
    secondary_value: Mapped[float | None]
    tertiary_value: Mapped[float | None]
    notes: Mapped[str | None] = mapped_column(Text)
    raw_payload_json: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="device_measurements")
    connection = relationship("DeviceConnection", back_populates="measurements")
