from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DeviceProviderResponse(BaseModel):
    code: str
    display_name: str
    summary: str
    category: str
    integration_kind: str
    connection_flow: str
    docs_url: str
    capabilities: list[str]
    setup_notes: list[str]
    is_wave_one: bool
    requires_vendor_contract: bool
    provider_configured: bool
    supports_live_sync: bool
    supports_manual_ingest: bool
    priority: int


class DeviceMeasurementResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    connection_id: UUID | None
    provider_code: str
    metric_type: str
    measured_at: datetime
    source_device_model: str | None
    unit: str | None
    primary_value: float | None
    secondary_value: float | None
    tertiary_value: float | None
    notes: str | None
    display_title: str
    display_value: str


class DeviceImportJobResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    connection_id: UUID | None
    provider_code: str
    status: str
    started_at: datetime
    completed_at: datetime | None
    item_count: int
    summary: str | None
    error_message: str | None


class DeviceConnectionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    provider_code: str
    provider_name: str
    integration_kind: str
    connection_flow: str
    status: str
    account_label: str | None
    external_user_id: str | None
    token_expires_at: datetime | None
    last_synced_at: datetime | None
    last_error: str | None
    measurement_count: int = 0
    latest_measurement: DeviceMeasurementResponse | None = None
    supports_live_sync: bool = False
    supports_manual_ingest: bool = False


class DeviceOverviewResponse(BaseModel):
    providers: list[DeviceProviderResponse]
    connections: list[DeviceConnectionResponse]
    recent_measurements: list[DeviceMeasurementResponse]
    recent_jobs: list[DeviceImportJobResponse]


class DeviceLinkRequest(BaseModel):
    account_label: str | None = Field(default=None, max_length=255)
    external_user_id: str | None = Field(default=None, max_length=255)
    authorization_code: str | None = Field(default=None, max_length=2048)
    access_token: str | None = Field(default=None, max_length=4096)
    refresh_token: str | None = Field(default=None, max_length=4096)
    api_key: str | None = Field(default=None, max_length=4096)
    token_expires_at: datetime | None = None
    scopes: list[str] = Field(default_factory=list)


class DeviceLinkResponse(BaseModel):
    message: str
    provider: DeviceProviderResponse
    connection: DeviceConnectionResponse | None = None
    next_step: str | None = None
    required_fields: list[str] = Field(default_factory=list)
    documentation_url: str | None = None


class DeviceMeasurementIngestItem(BaseModel):
    metric_type: str = Field(min_length=1, max_length=64)
    measured_at: datetime
    source_record_id: str | None = Field(default=None, max_length=255)
    source_device_model: str | None = Field(default=None, max_length=255)
    unit: str | None = Field(default=None, max_length=64)
    primary_value: float | None = None
    secondary_value: float | None = None
    tertiary_value: float | None = None
    notes: str | None = Field(default=None, max_length=1000)
    raw_payload: dict | None = None


class DeviceMeasurementIngestRequest(BaseModel):
    items: list[DeviceMeasurementIngestItem]


class DeviceMeasurementIngestResponse(BaseModel):
    created_count: int
    items: list[DeviceMeasurementResponse]


class DeviceSyncResponse(BaseModel):
    message: str
    job: DeviceImportJobResponse
    imported_count: int = 0
    items: list[DeviceMeasurementResponse] = Field(default_factory=list)
