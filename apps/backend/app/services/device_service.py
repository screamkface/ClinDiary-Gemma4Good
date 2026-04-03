from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.device_connection import DeviceConnection
from app.models.device_import_job import DeviceImportJob
from app.models.device_measurement import DeviceMeasurement
from app.models.enums import TimelineEventType
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.repositories.device_repository import DeviceRepository
from app.repositories.timeline_repository import TimelineRepository
from app.schemas.devices import (
    DeviceConnectionResponse,
    DeviceImportJobResponse,
    DeviceLinkRequest,
    DeviceLinkResponse,
    DeviceMeasurementIngestItem,
    DeviceMeasurementIngestRequest,
    DeviceMeasurementIngestResponse,
    DeviceMeasurementResponse,
    DeviceOverviewResponse,
    DeviceProviderResponse,
    DeviceSyncResponse,
)
from app.services.profile_context import resolve_user_profile
from app.core.config import get_settings


class DeviceProviderCode:
    OMRON = "omron"
    WITHINGS = "withings"
    IHEALTH = "ihealth"
    AD_MEDICAL = "ad_medical"
    DEXCOM = "dexcom"


class DeviceIntegrationKind:
    CLOUD_API = "cloud_api"
    SDK_BRIDGE = "sdk_bridge"
    API_KEY = "api_key"
    PARTNER_PLATFORM = "partner_platform"


class DeviceConnectionFlow:
    OAUTH2 = "oauth2"
    API_KEY = "api_key"
    PARTNER_SETUP = "partner_setup"
    SDK_BRIDGE = "sdk_bridge"


class DeviceConnectionStatus:
    PENDING = "pending"
    CONNECTED = "connected"
    ERROR = "error"
    DISCONNECTED = "disconnected"


class DeviceImportJobStatus:
    PENDING = "pending"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class DeviceMeasurementKind:
    BLOOD_PRESSURE = "blood_pressure"
    HEART_RATE = "heart_rate"
    SPO2 = "spo2"
    TEMPERATURE = "temperature"
    BODY_WEIGHT = "body_weight"
    BODY_COMPOSITION = "body_composition"
    BLOOD_GLUCOSE_BGM = "blood_glucose_bgm"
    BLOOD_GLUCOSE_CGM = "blood_glucose_cgm"


@dataclass(slots=True)
class DeviceProviderDefinition:
    code: str
    display_name: str
    summary: str
    category: str
    integration_kind: str
    connection_flow: str
    docs_url: str
    capabilities: tuple[str, ...]
    setup_notes: tuple[str, ...]
    priority: int
    is_wave_one: bool = True
    requires_vendor_contract: bool = False
    supports_live_sync: bool = False
    supports_manual_ingest: bool = False
    config_keys: tuple[str, ...] = ()

    def is_configured(self, settings) -> bool:
        if not self.config_keys:
            return True
        return all(bool(getattr(settings, key, None)) for key in self.config_keys)


class DeviceService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = DeviceRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.settings = get_settings()
        self.providers = {item.code: item for item in _build_provider_catalog()}

    def overview(self, user: User) -> DeviceOverviewResponse:
        profile = self._require_profile(user)
        provider_responses = [self._provider_response(item) for item in self._sorted_providers()]
        connections = self.repository.list_connections(profile.id)
        recent_measurements = self.repository.list_recent_measurements(profile.id, limit=25)
        recent_jobs = self.repository.list_recent_jobs(profile.id, limit=10)
        return DeviceOverviewResponse(
            providers=provider_responses,
            connections=[self._connection_response(connection) for connection in connections],
            recent_measurements=[self._measurement_response(item) for item in recent_measurements],
            recent_jobs=[DeviceImportJobResponse.model_validate(job) for job in recent_jobs],
        )

    def link_provider(
        self,
        user: User,
        provider_code: str,
        payload: DeviceLinkRequest,
    ) -> DeviceLinkResponse:
        profile = self._require_profile(user)
        provider = self._require_provider(provider_code)
        connection = self.repository.get_connection_for_provider(profile.id, provider.code)
        if connection is None:
            connection = DeviceConnection(
                patient_id=profile.id,
                provider_code=provider.code,
                provider_name=provider.display_name,
                integration_kind=provider.integration_kind,
                connection_flow=provider.connection_flow,
                status=DeviceConnectionStatus.PENDING,
            )
            self.repository.add_connection(connection)

        if payload.account_label is not None:
            connection.account_label = payload.account_label.strip() or None
        if payload.external_user_id is not None:
            connection.external_user_id = payload.external_user_id.strip() or None

        if provider.connection_flow == DeviceConnectionFlow.API_KEY:
            if not payload.api_key:
                self.db.flush()
                return DeviceLinkResponse(
                    message="Questo connettore richiede una API key o credenziali fornite dal vendor.",
                    provider=self._provider_response(provider),
                    connection=self._connection_response(connection),
                    next_step="provide_api_key",
                    required_fields=["api_key"],
                    documentation_url=provider.docs_url,
                )
            connection.api_key = payload.api_key.strip()
            connection.status = DeviceConnectionStatus.CONNECTED
            connection.last_error = None
            self.db.commit()
            self.db.refresh(connection)
            return DeviceLinkResponse(
                message=f"{provider.display_name} collegato. Puoi iniziare a inviare misure o usare il sync quando il vendor e` configurato.",
                provider=self._provider_response(provider),
                connection=self._connection_response(connection),
                next_step="ingest_or_sync",
                documentation_url=provider.docs_url,
            )

        if provider.connection_flow == DeviceConnectionFlow.PARTNER_SETUP:
            connection.status = DeviceConnectionStatus.PENDING
            connection.last_error = None
            self.db.commit()
            self.db.refresh(connection)
            return DeviceLinkResponse(
                message=(
                    f"{provider.display_name} richiede attivazione partner o SDK/BLE dedicato. "
                    "ClinDiary ha salvato il connettore per il profilo corrente."
                ),
                provider=self._provider_response(provider),
                connection=self._connection_response(connection),
                next_step="follow_partner_setup",
                documentation_url=provider.docs_url,
            )

        has_manual_tokens = bool(payload.access_token or payload.refresh_token)
        if not provider.is_configured(self.settings) and not has_manual_tokens:
            connection.status = DeviceConnectionStatus.PENDING
            connection.last_error = "Configurazione server del vendor mancante."
            self.db.commit()
            self.db.refresh(connection)
            return DeviceLinkResponse(
                message=(
                    f"{provider.display_name} e` supportato nell'architettura ClinDiary, "
                    "ma mancano ancora le credenziali server-side del vendor."
                ),
                provider=self._provider_response(provider),
                connection=self._connection_response(connection),
                next_step="configure_server_credentials",
                documentation_url=provider.docs_url,
            )

        if not has_manual_tokens and not payload.authorization_code:
            connection.status = DeviceConnectionStatus.PENDING
            self.db.commit()
            self.db.refresh(connection)
            return DeviceLinkResponse(
                message=(
                    f"{provider.display_name} usa un flusso OAuth2. "
                    "Per ora ClinDiary supporta il collegamento tramite token manuali o futura callback dedicata."
                ),
                provider=self._provider_response(provider),
                connection=self._connection_response(connection),
                next_step="provide_tokens",
                required_fields=["access_token"],
                documentation_url=provider.docs_url,
            )

        if payload.authorization_code and not payload.access_token:
            connection.status = DeviceConnectionStatus.PENDING
            connection.last_error = (
                "Authorization code ricevuto, ma lo scambio automatico code->token non e` ancora attivo in questo ambiente."
            )
            connection.metadata_json = json.dumps(
                {"authorization_code": payload.authorization_code},
                ensure_ascii=True,
            )
            self.db.commit()
            self.db.refresh(connection)
            return DeviceLinkResponse(
                message=(
                    "ClinDiary ha salvato il codice autorizzativo, ma per questo ambiente "
                    "serve ancora il token exchange lato vendor o token manuali."
                ),
                provider=self._provider_response(provider),
                connection=self._connection_response(connection),
                next_step="provide_tokens",
                documentation_url=provider.docs_url,
            )

        connection.access_token = payload.access_token.strip() if payload.access_token else None
        connection.refresh_token = payload.refresh_token.strip() if payload.refresh_token else None
        connection.token_expires_at = payload.token_expires_at
        connection.scopes_csv = ",".join(sorted({scope.strip() for scope in payload.scopes if scope.strip()})) or None
        connection.status = DeviceConnectionStatus.CONNECTED
        connection.last_error = None
        self.db.commit()
        self.db.refresh(connection)
        return DeviceLinkResponse(
            message=(
                f"{provider.display_name} collegato in modalita` token manuale. "
                "Quando abiliteremo il sync live del vendor, ClinDiary usera` queste credenziali."
            ),
            provider=self._provider_response(provider),
            connection=self._connection_response(connection),
            next_step="sync_when_ready",
            documentation_url=provider.docs_url,
        )

    def disconnect_connection(self, user: User, connection_id: UUID) -> None:
        profile = self._require_profile(user)
        connection = self.repository.get_connection(profile.id, connection_id)
        if connection is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device connection not found")
        self.repository.delete_connection(connection)
        self.db.commit()

    def sync_connection(self, user: User, connection_id: UUID) -> DeviceSyncResponse:
        profile = self._require_profile(user)
        connection = self.repository.get_connection(profile.id, connection_id)
        if connection is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device connection not found")

        provider = self._require_provider(connection.provider_code)
        job = DeviceImportJob(
            patient_id=profile.id,
            connection_id=connection.id,
            provider_code=connection.provider_code,
            status=DeviceImportJobStatus.FAILED,
            started_at=utcnow(),
            completed_at=utcnow(),
            item_count=0,
            summary="Sync manuale non ancora disponibile",
            error_message=(
                f"{provider.display_name} e` pronto come connettore Wave 1, "
                "ma il pull live richiede ancora token/vendor setup o SDK nativo."
            ),
        )
        self.repository.add_import_job(job)
        connection.last_error = job.error_message
        self.db.commit()
        self.db.refresh(job)
        self.db.refresh(connection)
        return DeviceSyncResponse(
            message=job.error_message or "Sync non disponibile.",
            job=DeviceImportJobResponse.model_validate(job),
            imported_count=0,
            items=[],
        )

    def ingest_measurements(
        self,
        user: User,
        connection_id: UUID,
        payload: DeviceMeasurementIngestRequest,
    ) -> DeviceMeasurementIngestResponse:
        profile = self._require_profile(user)
        connection = self.repository.get_connection(profile.id, connection_id)
        if connection is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device connection not found")

        provider = self._require_provider(connection.provider_code)
        if not provider.supports_manual_ingest:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Questo provider non supporta ingest manuale dal client ClinDiary.",
            )

        created: list[DeviceMeasurement] = []
        for item in payload.items:
            measurement = self._upsert_measurement(profile.id, connection, item)
            created.append(measurement)

        connection.status = DeviceConnectionStatus.CONNECTED
        connection.last_synced_at = utcnow()
        connection.last_error = None

        job = DeviceImportJob(
            patient_id=profile.id,
            connection_id=connection.id,
            provider_code=connection.provider_code,
            status=DeviceImportJobStatus.SUCCEEDED,
            started_at=utcnow(),
            completed_at=utcnow(),
            item_count=len(created),
            summary=f"{len(created)} misure importate da {provider.display_name}.",
        )
        self.repository.add_import_job(job)
        self._write_measurement_timeline_event(profile.id, connection, created)
        self.db.commit()
        for item in created:
            self.db.refresh(item)
        self.db.refresh(job)
        return DeviceMeasurementIngestResponse(
            created_count=len(created),
            items=[self._measurement_response(item) for item in created],
        )

    def _upsert_measurement(
        self,
        patient_id: UUID,
        connection: DeviceConnection,
        item: DeviceMeasurementIngestItem,
    ) -> DeviceMeasurement:
        metric_type = item.metric_type.strip().lower()
        existing = None
        if item.source_record_id:
            existing = self.repository.find_measurement_by_record(
                patient_id,
                connection.provider_code,
                metric_type,
                source_record_id=item.source_record_id.strip(),
            )
        if existing is None:
            existing = self.repository.find_measurement_by_timestamp(
                patient_id,
                connection.provider_code,
                metric_type,
                measured_at=item.measured_at,
            )

        measurement = existing or DeviceMeasurement(
            patient_id=patient_id,
            connection_id=connection.id,
            provider_code=connection.provider_code,
            metric_type=metric_type,
            measured_at=item.measured_at,
        )
        if existing is None:
            self.repository.add_measurement(measurement)

        measurement.source_record_id = item.source_record_id
        measurement.source_device_model = item.source_device_model
        measurement.unit = item.unit
        measurement.primary_value = item.primary_value
        measurement.secondary_value = item.secondary_value
        measurement.tertiary_value = item.tertiary_value
        measurement.notes = item.notes
        measurement.raw_payload_json = (
            json.dumps(item.raw_payload, ensure_ascii=True)
            if item.raw_payload is not None
            else None
        )
        return measurement

    def _write_measurement_timeline_event(
        self,
        patient_id: UUID,
        connection: DeviceConnection,
        measurements: list[DeviceMeasurement],
    ) -> None:
        if not measurements:
            return

        if len(measurements) == 1:
            latest = measurements[0]
            title = f"Misura da {connection.provider_name}"
            description = self._measurement_summary(latest)
            event_date = latest.measured_at
        else:
            latest = max(measurements, key=lambda item: item.measured_at)
            title = f"{len(measurements)} misure importate da {connection.provider_name}"
            summaries = [self._measurement_summary(item) for item in sorted(measurements, key=lambda item: item.measured_at, reverse=True)[:3]]
            description = " · ".join(summaries)
            event_date = latest.measured_at

        self.timeline_repository.upsert_source_event(
            patient_id=patient_id,
            source_type="device_connection",
            source_id=connection.id,
            event_type=TimelineEventType.VITAL_EVENT,
            title=title,
            description=description,
            event_date=event_date,
        )

    def _sorted_providers(self) -> list[DeviceProviderDefinition]:
        return sorted(self.providers.values(), key=lambda item: (item.priority, item.display_name.lower()))

    def _require_provider(self, provider_code: str) -> DeviceProviderDefinition:
        provider = self.providers.get(provider_code.strip().lower())
        if provider is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device provider not found")
        return provider

    def _provider_response(self, provider: DeviceProviderDefinition) -> DeviceProviderResponse:
        return DeviceProviderResponse(
            code=provider.code,
            display_name=provider.display_name,
            summary=provider.summary,
            category=provider.category,
            integration_kind=provider.integration_kind,
            connection_flow=provider.connection_flow,
            docs_url=provider.docs_url,
            capabilities=list(provider.capabilities),
            setup_notes=list(provider.setup_notes),
            is_wave_one=provider.is_wave_one,
            requires_vendor_contract=provider.requires_vendor_contract,
            provider_configured=provider.is_configured(self.settings),
            supports_live_sync=provider.supports_live_sync,
            supports_manual_ingest=provider.supports_manual_ingest,
            priority=provider.priority,
        )

    def _connection_response(self, connection: DeviceConnection) -> DeviceConnectionResponse:
        provider = self._require_provider(connection.provider_code)
        latest_measurement = self.repository.get_latest_measurement_for_connection(connection.id)
        return DeviceConnectionResponse(
            id=connection.id,
            provider_code=connection.provider_code,
            provider_name=connection.provider_name,
            integration_kind=connection.integration_kind,
            connection_flow=connection.connection_flow,
            status=connection.status,
            account_label=connection.account_label,
            external_user_id=connection.external_user_id,
            token_expires_at=connection.token_expires_at,
            last_synced_at=connection.last_synced_at,
            last_error=connection.last_error,
            measurement_count=self.repository.count_measurements_for_connection(connection.id),
            latest_measurement=self._measurement_response(latest_measurement) if latest_measurement else None,
            supports_live_sync=provider.supports_live_sync,
            supports_manual_ingest=provider.supports_manual_ingest,
        )

    def _measurement_response(self, measurement: DeviceMeasurement) -> DeviceMeasurementResponse:
        return DeviceMeasurementResponse(
            id=measurement.id,
            connection_id=measurement.connection_id,
            provider_code=measurement.provider_code,
            metric_type=measurement.metric_type,
            measured_at=measurement.measured_at,
            source_device_model=measurement.source_device_model,
            unit=measurement.unit,
            primary_value=measurement.primary_value,
            secondary_value=measurement.secondary_value,
            tertiary_value=measurement.tertiary_value,
            notes=measurement.notes,
            display_title=_measurement_title(measurement.metric_type),
            display_value=self._measurement_summary(measurement),
        )

    @staticmethod
    def _measurement_summary(measurement: DeviceMeasurement) -> str:
        metric_type = measurement.metric_type
        if metric_type == DeviceMeasurementKind.BLOOD_PRESSURE:
            systolic = _format_optional_number(measurement.primary_value)
            diastolic = _format_optional_number(measurement.secondary_value)
            pulse = _format_optional_number(measurement.tertiary_value)
            parts = []
            if systolic and diastolic:
                parts.append(f"{systolic}/{diastolic} {measurement.unit or 'mmHg'}")
            if pulse:
                parts.append(f"FC {pulse} bpm")
            return " · ".join(parts) or "Pressione registrata"
        if metric_type in {
            DeviceMeasurementKind.HEART_RATE,
            DeviceMeasurementKind.SPO2,
            DeviceMeasurementKind.TEMPERATURE,
            DeviceMeasurementKind.BODY_WEIGHT,
            DeviceMeasurementKind.BLOOD_GLUCOSE_BGM,
            DeviceMeasurementKind.BLOOD_GLUCOSE_CGM,
        }:
            value = _format_optional_number(measurement.primary_value)
            unit = measurement.unit or _default_unit(metric_type)
            return f"{value} {unit}".strip() if value else _measurement_title(metric_type)
        if metric_type == DeviceMeasurementKind.BODY_COMPOSITION:
            parts = []
            if measurement.primary_value is not None:
                parts.append(f"peso {_format_optional_number(measurement.primary_value)} kg")
            if measurement.secondary_value is not None:
                parts.append(f"grasso {_format_optional_number(measurement.secondary_value)}%")
            if measurement.tertiary_value is not None:
                parts.append(f"muscolo {_format_optional_number(measurement.tertiary_value)}%")
            return " · ".join(parts) or "Composizione corporea"
        return measurement.notes or _measurement_title(metric_type)

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile


def _build_provider_catalog() -> list[DeviceProviderDefinition]:
    return [
        DeviceProviderDefinition(
            code=DeviceProviderCode.OMRON,
            display_name="OMRON Connect",
            summary="Monitor pressione, peso, temperatura e altri device OMRON con SDK/BLE e API partner.",
            category="clinical_device",
            integration_kind=DeviceIntegrationKind.PARTNER_PLATFORM,
            connection_flow=DeviceConnectionFlow.PARTNER_SETUP,
            docs_url="https://omron-connect-create.readme.io/docs/getting-started",
            capabilities=("Pressione", "Frequenza cardiaca", "Peso", "Temperatura", "SpO2", "Glicemia"),
            setup_notes=(
                "Usa OMRON Connect Create come partner entry point.",
                "Per flussi mobile diretti ClinDiary usera` ingest da SDK/BLE sul device.",
                "Per flussi cloud servono approvazione partner e credenziali backend.",
            ),
            priority=10,
            supports_manual_ingest=True,
        ),
        DeviceProviderDefinition(
            code=DeviceProviderCode.WITHINGS,
            display_name="Withings",
            summary="Bilance, BPM, sonno e body composition via Public API OAuth2.",
            category="clinical_device",
            integration_kind=DeviceIntegrationKind.CLOUD_API,
            connection_flow=DeviceConnectionFlow.OAUTH2,
            docs_url="https://developer.withings.com/developer-guide/v3/withings-solutions/app-to-app-solution/",
            capabilities=("Pressione", "Peso", "Body composition", "Sonno", "Attivita`"),
            setup_notes=(
                "Richiede app registration Withings e redirect URI server-side.",
                "ClinDiary puo` gia` salvare token manuali per ambienti partner/debug.",
            ),
            priority=20,
            config_keys=("withings_client_id", "withings_client_secret", "withings_redirect_uri"),
        ),
        DeviceProviderDefinition(
            code=DeviceProviderCode.IHEALTH,
            display_name="iHealth",
            summary="Pressione, peso, glicemia, SpO2 e temperatura via Open API.",
            category="clinical_device",
            integration_kind=DeviceIntegrationKind.CLOUD_API,
            connection_flow=DeviceConnectionFlow.OAUTH2,
            docs_url="https://developer.ihealthlabs.com/dev_documentation_openapidoc.htm",
            capabilities=("Pressione", "Peso", "Glicemia", "SpO2", "Temperatura", "Sonno", "Attivita`"),
            setup_notes=(
                "Richiede credenziali Open API e redirect URI registrato.",
                "ClinDiary supporta gia` il collegamento manuale di token per bootstrap/testing.",
            ),
            priority=30,
            config_keys=("ihealth_client_id", "ihealth_client_secret", "ihealth_redirect_uri"),
        ),
        DeviceProviderDefinition(
            code=DeviceProviderCode.AD_MEDICAL,
            display_name="A&D Medical",
            summary="Pressione, peso, pulsossimetri e termometri via API o SDK.",
            category="clinical_device",
            integration_kind=DeviceIntegrationKind.API_KEY,
            connection_flow=DeviceConnectionFlow.API_KEY,
            docs_url="https://medical.andonline.com/API-license-agreement/",
            capabilities=("Pressione", "Peso", "SpO2", "Temperatura", "Attivita`"),
            setup_notes=(
                "A&D espone API licenziata e risorse SDK.",
                "ClinDiary supporta gia` il salvataggio della API key e ingest manuale dal client.",
            ),
            priority=40,
            supports_manual_ingest=True,
        ),
        DeviceProviderDefinition(
            code=DeviceProviderCode.DEXCOM,
            display_name="Dexcom",
            summary="Dati CGM via API OAuth2 per partner autorizzati.",
            category="diabetes",
            integration_kind=DeviceIntegrationKind.CLOUD_API,
            connection_flow=DeviceConnectionFlow.OAUTH2,
            docs_url="https://developer.dexcom.com/docs/",
            capabilities=("CGM", "Eventi diabete"),
            setup_notes=(
                "Richiede registrazione come Digital Health Partner Dexcom.",
                "ClinDiary supporta gia` collegamento token/manual bootstrap per ambienti autorizzati.",
            ),
            priority=50,
            requires_vendor_contract=True,
            config_keys=("dexcom_client_id", "dexcom_client_secret", "dexcom_redirect_uri"),
        ),
    ]


def _measurement_title(metric_type: str) -> str:
    labels = {
        DeviceMeasurementKind.BLOOD_PRESSURE: "Pressione arteriosa",
        DeviceMeasurementKind.HEART_RATE: "Frequenza cardiaca",
        DeviceMeasurementKind.SPO2: "Saturazione ossigeno",
        DeviceMeasurementKind.TEMPERATURE: "Temperatura",
        DeviceMeasurementKind.BODY_WEIGHT: "Peso",
        DeviceMeasurementKind.BODY_COMPOSITION: "Composizione corporea",
        DeviceMeasurementKind.BLOOD_GLUCOSE_BGM: "Glicemia",
        DeviceMeasurementKind.BLOOD_GLUCOSE_CGM: "Glucosio continuo",
    }
    return labels.get(metric_type, metric_type.replace("_", " ").title())


def _default_unit(metric_type: str) -> str:
    units = {
        DeviceMeasurementKind.HEART_RATE: "bpm",
        DeviceMeasurementKind.SPO2: "%",
        DeviceMeasurementKind.TEMPERATURE: "°C",
        DeviceMeasurementKind.BODY_WEIGHT: "kg",
        DeviceMeasurementKind.BLOOD_GLUCOSE_BGM: "mg/dL",
        DeviceMeasurementKind.BLOOD_GLUCOSE_CGM: "mg/dL",
    }
    return units.get(metric_type, "")


def _format_optional_number(value: float | None) -> str | None:
    if value is None:
        return None
    if float(value).is_integer():
        return str(int(value))
    return f"{value:.1f}"
