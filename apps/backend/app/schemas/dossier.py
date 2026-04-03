from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.enums import (
    BiologicalSex,
    ClinicalDocumentType,
    DocumentContextStatus,
    DocumentParsedStatus,
    DossierShareScope,
    ReportType,
)
from app.schemas.profile import PatientProfileResponse
from app.schemas.alerts import AlertResponse
from app.schemas.daily_entries import DailyEntryResponse
from app.schemas.insights import InsightSummaryResponse
from app.schemas.profile import (
    AllergyResponse,
    ClinicalEpisodeResponse,
    ConditionResponse,
    FamilyHistoryResponse,
    MedicationResponse,
    VaccinationRecordResponse,
)
from app.schemas.wearables import WearableDailySummaryResponse


class DossierProfileFactResponse(BaseModel):
    label: str
    value: str


class DossierProvenanceFactResponse(BaseModel):
    label: str
    value: str


class DossierDocumentResponse(BaseModel):
    id: UUID
    title: str
    document_type: ClinicalDocumentType
    upload_date: datetime
    exam_date: date | None
    source: str | None
    parsed_status: DocumentParsedStatus
    context_status: DocumentContextStatus


class DossierLabPanelResponse(BaseModel):
    document_id: UUID
    document_title: str
    panel_name: str
    panel_date: date | None
    abnormal_results_count: int
    key_results: list[str]


class DossierImagingReportResponse(BaseModel):
    document_id: UUID
    document_title: str
    exam_date: date | None
    exam_type: str | None
    body_part: str | None
    impression: str | None


class DossierReportSummaryResponse(BaseModel):
    id: UUID
    report_type: ReportType
    title: str
    period_start: date
    period_end: date
    generated_at: datetime
    summary_excerpt: str | None


class DossierDeviceMeasurementSummaryResponse(BaseModel):
    provider_code: str
    provider_name: str
    metric_type: str
    metric_label: str
    measurement_count: int
    latest_measured_at: datetime
    latest_value: str
    trend_label: str | None = None
    concern_level: str | None = None
    concern_note: str | None = None
    summary: str


class DossierEmergencySummaryResponse(BaseModel):
    generated_at: datetime
    headline: str
    key_points: list[str]
    active_problems: list[str] = Field(default_factory=list)
    active_medications: list[str]
    allergies: list[str]
    conditions: list[str]
    open_alerts: list[str]
    latest_wearable_summary: str | None = None
    latest_report_summary: str | None = None


class DossierResponse(BaseModel):
    generated_at: datetime
    display_name: str
    age: int | None
    biological_sex: BiologicalSex | None
    profile_snapshot: PatientProfileResponse
    profile_facts: list[DossierProfileFactResponse]
    provenance_facts: list[DossierProvenanceFactResponse]
    emergency_summary: DossierEmergencySummaryResponse
    allergies: list[AllergyResponse]
    medical_conditions: list[ConditionResponse]
    medications: list[MedicationResponse]
    family_history: list[FamilyHistoryResponse]
    vaccinations: list[VaccinationRecordResponse]
    clinical_episodes: list[ClinicalEpisodeResponse] = Field(default_factory=list)
    recent_daily_entries: list[DailyEntryResponse]
    recent_documents: list[DossierDocumentResponse]
    recent_lab_panels: list[DossierLabPanelResponse]
    recent_imaging_reports: list[DossierImagingReportResponse]
    device_measurement_summaries: list[DossierDeviceMeasurementSummaryResponse]
    recent_insights: list[InsightSummaryResponse]
    recent_reports: list[DossierReportSummaryResponse]
    alerts: list[AlertResponse]
    wearable_summaries: list[WearableDailySummaryResponse]


class DossierShareCreateRequest(BaseModel):
    scope: DossierShareScope = DossierShareScope.FULL
    label: str | None = None
    expires_in_days: int = Field(default=7, ge=1, le=30)


class DossierShareLinkResponse(BaseModel):
    id: UUID
    scope: DossierShareScope
    label: str | None
    filename: str
    mime_type: str
    share_url: str | None = None
    expires_at: datetime
    revoked_at: datetime | None
    last_accessed_at: datetime | None
    created_at: datetime


class DossierImportRequest(BaseModel):
    snapshot: DossierResponse
    replace_existing: bool = True
