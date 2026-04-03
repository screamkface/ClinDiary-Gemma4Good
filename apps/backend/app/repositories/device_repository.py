from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.device_connection import DeviceConnection
from app.models.device_import_job import DeviceImportJob
from app.models.device_measurement import DeviceMeasurement


class DeviceRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_connection(self, patient_id: UUID, connection_id: UUID) -> DeviceConnection | None:
        stmt = select(DeviceConnection).where(
            DeviceConnection.patient_id == patient_id,
            DeviceConnection.id == connection_id,
        )
        return self.db.scalar(stmt)

    def get_connection_for_provider(
        self,
        patient_id: UUID,
        provider_code: str,
    ) -> DeviceConnection | None:
        stmt = select(DeviceConnection).where(
            DeviceConnection.patient_id == patient_id,
            DeviceConnection.provider_code == provider_code,
        )
        return self.db.scalar(stmt)

    def list_connections(self, patient_id: UUID) -> list[DeviceConnection]:
        stmt = (
            select(DeviceConnection)
            .where(DeviceConnection.patient_id == patient_id)
            .order_by(DeviceConnection.provider_name.asc(), DeviceConnection.created_at.asc())
        )
        return list(self.db.scalars(stmt))

    def add_connection(self, connection: DeviceConnection) -> DeviceConnection:
        self.db.add(connection)
        return connection

    def delete_connection(self, connection: DeviceConnection) -> None:
        self.db.delete(connection)

    def add_import_job(self, job: DeviceImportJob) -> DeviceImportJob:
        self.db.add(job)
        return job

    def list_recent_jobs(self, patient_id: UUID, *, limit: int = 10) -> list[DeviceImportJob]:
        stmt = (
            select(DeviceImportJob)
            .where(DeviceImportJob.patient_id == patient_id)
            .order_by(DeviceImportJob.started_at.desc())
            .limit(limit)
        )
        return list(self.db.scalars(stmt))

    def find_measurement_by_record(
        self,
        patient_id: UUID,
        provider_code: str,
        metric_type: str,
        *,
        source_record_id: str,
    ) -> DeviceMeasurement | None:
        stmt = select(DeviceMeasurement).where(
            DeviceMeasurement.patient_id == patient_id,
            DeviceMeasurement.provider_code == provider_code,
            DeviceMeasurement.metric_type == metric_type,
            DeviceMeasurement.source_record_id == source_record_id,
        )
        return self.db.scalar(stmt)

    def find_measurement_by_timestamp(
        self,
        patient_id: UUID,
        provider_code: str,
        metric_type: str,
        *,
        measured_at: datetime,
    ) -> DeviceMeasurement | None:
        stmt = select(DeviceMeasurement).where(
            DeviceMeasurement.patient_id == patient_id,
            DeviceMeasurement.provider_code == provider_code,
            DeviceMeasurement.metric_type == metric_type,
            DeviceMeasurement.measured_at == measured_at,
        )
        return self.db.scalar(stmt)

    def add_measurement(self, measurement: DeviceMeasurement) -> DeviceMeasurement:
        self.db.add(measurement)
        return measurement

    def list_recent_measurements(
        self,
        patient_id: UUID,
        *,
        limit: int = 30,
        provider_code: str | None = None,
    ) -> list[DeviceMeasurement]:
        stmt = select(DeviceMeasurement).where(DeviceMeasurement.patient_id == patient_id)
        if provider_code is not None:
            stmt = stmt.where(DeviceMeasurement.provider_code == provider_code)
        stmt = stmt.order_by(DeviceMeasurement.measured_at.desc(), DeviceMeasurement.created_at.desc()).limit(limit)
        return list(self.db.scalars(stmt))

    def list_for_patient_between(
        self,
        patient_id: UUID,
        *,
        start_at: datetime,
        end_at: datetime,
        limit: int = 500,
    ) -> list[DeviceMeasurement]:
        stmt = (
            select(DeviceMeasurement)
            .where(
                DeviceMeasurement.patient_id == patient_id,
                DeviceMeasurement.measured_at >= start_at,
                DeviceMeasurement.measured_at <= end_at,
            )
            .order_by(DeviceMeasurement.measured_at.desc(), DeviceMeasurement.created_at.desc())
            .limit(limit)
        )
        return list(self.db.scalars(stmt))

    def count_measurements_for_connection(self, connection_id: UUID) -> int:
        stmt = select(func.count(DeviceMeasurement.id)).where(DeviceMeasurement.connection_id == connection_id)
        return int(self.db.scalar(stmt) or 0)

    def get_latest_measurement_for_connection(self, connection_id: UUID) -> DeviceMeasurement | None:
        stmt = (
            select(DeviceMeasurement)
            .where(DeviceMeasurement.connection_id == connection_id)
            .order_by(DeviceMeasurement.measured_at.desc(), DeviceMeasurement.created_at.desc())
            .limit(1)
        )
        return self.db.scalar(stmt)
