from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class DeviceConnection(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "device_connections"
    __table_args__ = (
        UniqueConstraint("patient_id", "provider_code", name="uq_device_connection_patient_provider"),
    )

    patient_id: Mapped[str] = mapped_column(ForeignKey("patient_profiles.id", ondelete="CASCADE"))
    provider_code: Mapped[str] = mapped_column(String(64), nullable=False)
    provider_name: Mapped[str] = mapped_column(String(120), nullable=False)
    integration_kind: Mapped[str] = mapped_column(String(32), nullable=False)
    connection_flow: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending")
    account_label: Mapped[str | None] = mapped_column(String(255))
    external_user_id: Mapped[str | None] = mapped_column(String(255))
    access_token: Mapped[str | None] = mapped_column(Text)
    refresh_token: Mapped[str | None] = mapped_column(Text)
    api_key: Mapped[str | None] = mapped_column(Text)
    token_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    scopes_csv: Mapped[str | None] = mapped_column(Text)
    metadata_json: Mapped[str | None] = mapped_column(Text)
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_error: Mapped[str | None] = mapped_column(Text)

    patient = relationship("PatientProfile", back_populates="device_connections")
    import_jobs = relationship(
        "DeviceImportJob",
        back_populates="connection",
        cascade="all, delete-orphan",
    )
    measurements = relationship(
        "DeviceMeasurement",
        back_populates="connection",
        cascade="all, delete-orphan",
    )
