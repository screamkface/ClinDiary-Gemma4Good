from __future__ import annotations

import json
from datetime import date, timedelta, timezone
from secrets import token_urlsafe

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_token, utcnow
from app.core.storage import get_storage_service
from app.models.allergy import Allergy
from app.models.clinical_episode import ClinicalEpisode
from app.models.dossier_share_link import DossierShareLink
from app.models.enums import AlertStatus, DocumentContextStatus, DossierShareScope
from app.models.family_history import FamilyHistoryEntry
from app.models.medical_condition import MedicalCondition
from app.models.medication import Medication
from app.models.medication_schedule import MedicationSchedule
from app.models.patient_profile import PatientProfile
from app.models.vaccination_record import VaccinationRecord
from app.models.user import User
from app.repositories.alert_repository import AlertRepository
from app.repositories.daily_entry_repository import DailyEntryRepository
from app.repositories.device_repository import DeviceRepository
from app.repositories.document_repository import DocumentRepository
from app.repositories.insight_repository import InsightRepository
from app.repositories.profile_repository import ProfileRepository
from app.repositories.report_repository import ReportRepository
from app.repositories.wearable_repository import WearableRepository
from app.services.profile_context import resolve_user_profile
from app.schemas.alerts import AlertResponse
from app.schemas.daily_entries import DailyEntryResponse
from app.schemas.dossier import (
    DossierDocumentResponse,
    DossierDeviceMeasurementSummaryResponse,
    DossierEmergencySummaryResponse,
    DossierImportRequest,
    DossierImagingReportResponse,
    DossierLabPanelResponse,
    DossierProfileFactResponse,
    DossierProvenanceFactResponse,
    DossierReportSummaryResponse,
    DossierShareCreateRequest,
    DossierResponse,
)
from app.schemas.insights import InsightSummaryResponse
from app.schemas.profile import (
    AllergyResponse,
    ClinicalEpisodeResponse,
    ConditionResponse,
    FamilyHistoryResponse,
    MedicationResponse,
    PatientProfileResponse,
    VaccinationRecordResponse,
)
from app.schemas.wearables import WearableDailySummaryResponse
from app.services.audit_service import AuditService
from app.services.device_measurement_summary_service import summarize_device_measurements
from app.services.report_pdf_builder import ReportPdfBuilder
from app.services.notification_service import NotificationService
from app.services.screening_service import ScreeningService


class DossierService:
    _RECENT_DAILY_ENTRY_COUNT = 5
    _RECENT_DOCUMENT_COUNT = 6
    _RECENT_LAB_PANEL_COUNT = 4
    _RECENT_IMAGING_COUNT = 4
    _RECENT_REPORT_COUNT = 4
    _RECENT_WEARABLE_COUNT = 7
    _RECENT_DEVICE_MEASUREMENT_COUNT = 6
    _RECENT_INSIGHT_DAYS = 120
    _RECENT_VACCINATION_COUNT = 6

    def __init__(self, db: Session) -> None:
        self.db = db
        self.profile_repository = ProfileRepository(db)
        self.daily_entry_repository = DailyEntryRepository(db)
        self.device_repository = DeviceRepository(db)
        self.document_repository = DocumentRepository(db)
        self.insight_repository = InsightRepository(db)
        self.report_repository = ReportRepository(db)
        self.alert_repository = AlertRepository(db)
        self.wearable_repository = WearableRepository(db)
        self.storage_service = get_storage_service()
        self.audit_service = AuditService(db)
        self.pdf_builder = ReportPdfBuilder()

    def get_dossier(self, user: User) -> DossierResponse:
        profile = self._require_profile(user)
        bundle = self.profile_repository.get_profile_by_patient_id(profile.id)
        if bundle is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

        recent_entries = self.daily_entry_repository.list_for_patient(profile.id)[: self._RECENT_DAILY_ENTRY_COUNT]
        documents = self.document_repository.list_for_patient_with_details(
            profile.id,
            context_status=DocumentContextStatus.ACTIVE,
        )
        recent_documents = documents[: self._RECENT_DOCUMENT_COUNT]
        reports = self.report_repository.list_recent_for_patient(
            profile.id,
            limit=self._RECENT_REPORT_COUNT,
        )
        insights = list(
            reversed(
                self.insight_repository.list_between(
                    patient_id=profile.id,
                    start_date=date.today() - timedelta(days=self._RECENT_INSIGHT_DAYS),
                    end_date=date.today(),
                )
            )
        )[: self._RECENT_REPORT_COUNT]
        alerts = self.alert_repository.list_for_patient(profile.id, status=AlertStatus.OPEN)[:6]
        wearables = self.wearable_repository.list_recent_for_patient(
            profile.id,
            limit=self._RECENT_WEARABLE_COUNT,
        )
        device_measurement_summaries = self._device_measurement_summaries(profile.id)
        provenance_facts = self._provenance_facts(
            bundle,
            documents=documents,
            reports=reports,
            insights=insights,
            wearables=wearables,
            device_measurement_summaries=device_measurement_summaries,
            recent_daily_entries=recent_entries,
        )
        emergency_summary = self._emergency_summary(
            bundle,
            recent_daily_entries=recent_entries,
            reports=reports,
            alerts=alerts,
            wearables=wearables,
            clinical_episodes=bundle.clinical_episodes,
        )

        return DossierResponse(
            generated_at=utcnow(),
            display_name=self._display_name(bundle),
            age=self._age(bundle.birth_date),
            biological_sex=bundle.biological_sex,
            profile_snapshot=PatientProfileResponse.model_validate(bundle),
            profile_facts=self._profile_facts(bundle),
            provenance_facts=provenance_facts,
            emergency_summary=emergency_summary,
            allergies=[AllergyResponse.model_validate(item) for item in bundle.allergies],
            medical_conditions=[ConditionResponse.model_validate(item) for item in bundle.conditions],
            medications=[MedicationResponse.model_validate(item) for item in bundle.medications],
            family_history=[FamilyHistoryResponse.model_validate(item) for item in bundle.family_history_entries],
            vaccinations=[
                VaccinationRecordResponse.model_validate(item)
                for item in self._sorted_vaccinations(bundle)[: self._RECENT_VACCINATION_COUNT]
            ],
            clinical_episodes=[
                ClinicalEpisodeResponse.model_validate(item)
                for item in self._sorted_clinical_episodes(bundle)
            ],
            recent_daily_entries=[DailyEntryResponse.model_validate(item) for item in recent_entries],
            recent_documents=[
                DossierDocumentResponse(
                    id=item.id,
                    title=item.title,
                    document_type=item.document_type,
                    upload_date=item.upload_date,
                    exam_date=item.exam_date,
                    source=item.source,
                    parsed_status=item.parsed_status,
                    context_status=item.context_status,
                )
                for item in recent_documents
            ],
            recent_lab_panels=self._lab_panel_highlights(documents),
            recent_imaging_reports=self._imaging_highlights(documents),
            device_measurement_summaries=device_measurement_summaries,
            recent_insights=[InsightSummaryResponse.model_validate(item) for item in insights],
            recent_reports=[
                DossierReportSummaryResponse(
                    id=item.id,
                    report_type=item.report_type,
                    title=item.title,
                    period_start=item.period_start,
                    period_end=item.period_end,
                    generated_at=item.generated_at,
                    summary_excerpt=item.summary_excerpt,
                )
                for item in reports
            ],
            alerts=[AlertResponse.model_validate(item) for item in alerts],
            wearable_summaries=[WearableDailySummaryResponse.model_validate(item) for item in wearables],
        )

    def export_dossier(self, user: User) -> tuple[str, bytes]:
        dossier = self.get_dossier(user)
        sections = [
            ("Profilo", self._profile_lines(dossier)),
            ("Scheda emergenza", self._emergency_lines(dossier)),
            ("Provenienza dati", self._provenance_lines(dossier)),
            ("Contesto clinico", self._context_lines(dossier)),
            ("Problemi clinici", self._episode_lines(dossier)),
            ("Farmaci attuali", self._medication_lines(dossier)),
            ("Storico vaccinale", self._vaccination_lines(dossier)),
            ("Diario recente", self._daily_entry_lines(dossier)),
            ("Documenti e referti recenti", self._document_lines(dossier)),
            ("Dispositivi clinici", self._device_measurement_lines(dossier)),
            ("Insight, report e alert", self._insight_lines(dossier)),
            ("Dati smartwatch", self._wearable_lines(dossier)),
        ]
        pdf_bytes = self.pdf_builder.build(
            title="ClinDiary - Dossier salute",
            subtitle=f"Generato il {dossier.generated_at.astimezone().strftime('%d/%m/%Y %H:%M')}",
            sections=sections,
        )
        return "dossier-salute.pdf", pdf_bytes

    def export_dossier_json(self, user: User) -> tuple[str, bytes]:
        dossier = self.get_dossier(user)
        payload = json.dumps(dossier.model_dump(mode="json"), ensure_ascii=False, indent=2).encode("utf-8")
        return "dossier-salute.json", payload

    def export_emergency_dossier(self, user: User) -> tuple[str, bytes]:
        dossier = self.get_dossier(user)
        sections = [
            ("Scheda emergenza", self._emergency_lines(dossier)),
            ("Problemi clinici", self._episode_lines(dossier)),
            ("Farmaci attivi", self._medication_lines(dossier)),
            ("Allergie e condizioni", self._context_lines(dossier)),
            ("Provenienza dati", self._provenance_lines(dossier)),
            ("Alert e ultimo contesto", self._insight_lines(dossier)),
        ]
        pdf_bytes = self.pdf_builder.build(
            title="ClinDiary - Scheda emergenza",
            subtitle=f"Generata il {dossier.generated_at.astimezone().strftime('%d/%m/%Y %H:%M')}",
            sections=sections,
        )
        return "scheda-emergenza.pdf", pdf_bytes

    def list_share_links(self, user: User) -> list[DossierShareLink]:
        profile = self._require_profile(user)
        self.cleanup_expired_share_links(patient_id=profile.id)
        stmt = (
            select(DossierShareLink)
            .where(DossierShareLink.patient_id == profile.id)
            .order_by(DossierShareLink.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def create_share_link(
        self,
        user: User,
        payload: DossierShareCreateRequest,
    ) -> tuple[DossierShareLink, str]:
        profile = self._require_profile(user)
        self.cleanup_expired_share_links(patient_id=profile.id)
        if payload.scope == DossierShareScope.FULL:
            filename, content = self.export_dossier(user)
        else:
            filename, content = self.export_emergency_dossier(user)

        object_key = f"patients/{profile.id}/share-links/{token_urlsafe(16)}-{filename}"
        stored = self.storage_service.save_bytes(
            object_key=object_key,
            data=content,
            content_type="application/pdf",
        )
        share_token = token_urlsafe(32)
        share_link = DossierShareLink(
            patient_id=profile.id,
            token_hash=hash_token(share_token),
            scope=payload.scope,
            label=(payload.label or "").strip() or None,
            filename=filename,
            mime_type="application/pdf",
            object_key=stored.object_key,
            expires_at=utcnow() + timedelta(days=payload.expires_in_days),
        )
        self.db.add(share_link)
        self.audit_service.log_for_user(
            user,
            event_type="dossier_share_link_created",
            entity_type="dossier_share_link",
            entity_id=share_link.id,
            summary=f"Link sicuro creato: {share_link.scope.value}",
            metadata={
                "scope": share_link.scope.value,
                "expires_at": share_link.expires_at.isoformat(),
            },
        )
        self.db.commit()
        self.db.refresh(share_link)
        return share_link, share_token

    def revoke_share_link(self, user: User, share_link_id) -> DossierShareLink:
        profile = self._require_profile(user)
        share_link = self._require_owned_resource(
            DossierShareLink,
            profile.id,
            share_link_id,
            "Share link not found",
        )
        share_link.revoked_at = utcnow()
        self.storage_service.delete_bytes(share_link.object_key)
        self.audit_service.log_for_user(
            user,
            event_type="dossier_share_link_revoked",
            entity_type="dossier_share_link",
            entity_id=share_link.id,
            summary=f"Link sicuro revocato: {share_link.scope.value}",
        )
        self.db.commit()
        self.db.refresh(share_link)
        return share_link

    def cleanup_expired_share_links(self, *, patient_id=None) -> int:
        now = utcnow()
        stmt = select(DossierShareLink)
        if patient_id is not None:
            stmt = stmt.where(DossierShareLink.patient_id == patient_id)
        links = list(self.db.scalars(stmt))
        removed = 0
        for share_link in links:
            expires_at = share_link.expires_at
            if expires_at.tzinfo is None or expires_at.tzinfo.utcoffset(expires_at) is None:
                expires_at = expires_at.replace(tzinfo=timezone.utc)
            else:
                expires_at = expires_at.astimezone(timezone.utc)
            if share_link.revoked_at is None and expires_at > now:
                continue
            self.storage_service.delete_bytes(share_link.object_key)
            self.db.delete(share_link)
            removed += 1
        if removed:
            self.db.commit()
        return removed

    def get_shared_file(self, token: str) -> tuple[DossierShareLink, bytes]:
        token_hash = hash_token(token)
        stmt = select(DossierShareLink).where(DossierShareLink.token_hash == token_hash)
        share_link = self.db.scalar(stmt)
        if share_link is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Share link not found")
        expires_at = share_link.expires_at
        if expires_at.tzinfo is None or expires_at.tzinfo.utcoffset(expires_at) is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        else:
            expires_at = expires_at.astimezone(timezone.utc)
        if share_link.revoked_at is not None or expires_at <= utcnow():
            self.storage_service.delete_bytes(share_link.object_key)
            self.db.delete(share_link)
            self.db.commit()
            raise HTTPException(status_code=status.HTTP_410_GONE, detail="Share link expired")
        share_link.last_accessed_at = utcnow()
        self.db.commit()
        self.db.refresh(share_link)
        return share_link, self.storage_service.read_bytes(share_link.object_key)

    def import_dossier(self, user: User, payload: DossierImportRequest) -> DossierResponse:
        profile = self._require_profile(user)
        bundle = self.profile_repository.get_profile_by_patient_id(profile.id)
        if bundle is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

        snapshot = payload.snapshot
        self._apply_profile_snapshot(profile, snapshot.profile_snapshot)

        if payload.replace_existing:
            self._clear_profile_resources(bundle)

        self._restore_allergies(profile.id, snapshot.allergies)
        self._restore_conditions(profile.id, snapshot.medical_conditions)
        self._restore_family_history(profile.id, snapshot.family_history)
        self._restore_vaccinations(profile.id, snapshot.vaccinations)
        self._restore_clinical_episodes(profile.id, snapshot.clinical_episodes)
        self._restore_medications(profile.id, snapshot.medications)

        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)
        return self.get_dossier(user)

    def _apply_profile_snapshot(self, profile: PatientProfile, snapshot: PatientProfileResponse) -> None:
        for field in (
            "first_name",
            "last_name",
            "birth_date",
            "biological_sex",
            "height_cm",
            "weight_kg",
            "smoker",
            "alcohol_use",
            "activity_level",
            "region_code",
            "occupation",
            "exercise_habits",
            "sleep_pattern",
            "symptom_triggers",
            "functional_limitations",
        ):
            setattr(profile, field, getattr(snapshot, field))

    def _clear_profile_resources(self, bundle: PatientProfile) -> None:
        for item in (
            list(bundle.allergies)
            + list(bundle.conditions)
            + list(bundle.medications)
            + list(bundle.family_history_entries)
            + list(bundle.vaccination_records)
            + list(bundle.clinical_episodes)
        ):
            self.db.delete(item)

    def _restore_allergies(self, profile_id, items) -> None:
        for item in items:
            self.db.add(
                Allergy(
                    patient_id=profile_id,
                    allergen=item.allergen,
                    severity=item.severity,
                    notes=item.notes,
                )
            )

    def _restore_conditions(self, profile_id, items) -> None:
        for item in items:
            self.db.add(
                MedicalCondition(
                    patient_id=profile_id,
                    name=item.name,
                    diagnosis_date=item.diagnosis_date,
                    status=item.status,
                    notes=item.notes,
                )
            )

    def _restore_family_history(self, profile_id, items) -> None:
        for item in items:
            self.db.add(
                FamilyHistoryEntry(
                    patient_id=profile_id,
                    relation=item.relation,
                    condition_name=item.condition_name,
                    notes=item.notes,
                )
            )

    def _restore_vaccinations(self, profile_id, items) -> None:
        for item in items:
            self.db.add(
                VaccinationRecord(
                    patient_id=profile_id,
                    vaccine_name=item.vaccine_name,
                    administered_on=item.administered_on,
                    dose_number=item.dose_number,
                    next_due_date=item.next_due_date,
                    provider_name=item.provider_name,
                    notes=item.notes,
                )
            )

    def _restore_clinical_episodes(self, profile_id, items) -> None:
        for item in items:
            self.db.add(
                ClinicalEpisode(
                    patient_id=profile_id,
                    title=item.title,
                    summary=item.summary,
                    status=item.status,
                    onset_date=item.onset_date,
                    resolved_date=item.resolved_date,
                    next_review_date=item.next_review_date,
                    notes=item.notes,
                )
            )

    def _restore_medications(self, profile_id, items) -> None:
        for item in items:
            medication = Medication(
                patient_id=profile_id,
                name=item.name,
                dosage=item.dosage,
                frequency=item.frequency,
                route=item.route,
                start_date=item.start_date,
                end_date=item.end_date,
                active=item.active,
                notes=item.notes,
            )
            self.db.add(medication)
            self.db.flush()
            for schedule in item.schedules:
                medication.schedules.append(
                    MedicationSchedule(
                        medication_id=medication.id,
                        scheduled_time=schedule.scheduled_time,
                        days_of_week_csv=",".join(str(day) for day in schedule.days_of_week) or None,
                        start_date=schedule.start_date,
                        end_date=schedule.end_date,
                        cycle_days_on=schedule.cycle_days_on,
                        cycle_days_off=schedule.cycle_days_off,
                        paused_until=schedule.paused_until,
                        instructions=schedule.instructions,
                        active=schedule.active,
                    )
                )

    def _lab_panel_highlights(self, documents) -> list[DossierLabPanelResponse]:
        items: list[DossierLabPanelResponse] = []
        for document in documents:
            for panel in document.lab_panels:
                abnormal_results = [result for result in panel.results if result.abnormal_flag]
                key_results = abnormal_results or list(panel.results[:3])
                items.append(
                    DossierLabPanelResponse(
                        document_id=document.id,
                        document_title=document.title,
                        panel_name=panel.panel_name,
                        panel_date=panel.panel_date,
                        abnormal_results_count=len(abnormal_results),
                        key_results=[
                            self._lab_result_label(result.analyte_name, result.value, result.unit)
                            for result in key_results
                        ],
                    )
                )
        items.sort(key=lambda item: item.panel_date or date.min, reverse=True)
        return items[: self._RECENT_LAB_PANEL_COUNT]

    def _imaging_highlights(self, documents) -> list[DossierImagingReportResponse]:
        items: list[DossierImagingReportResponse] = []
        for document in documents:
            for report in document.imaging_reports:
                items.append(
                    DossierImagingReportResponse(
                        document_id=document.id,
                        document_title=document.title,
                        exam_date=document.exam_date,
                        exam_type=report.exam_type,
                        body_part=report.body_part,
                        impression=report.impression,
                    )
                )
        items.sort(key=lambda item: item.exam_date or date.min, reverse=True)
        return items[: self._RECENT_IMAGING_COUNT]

    @staticmethod
    def _profile_facts(profile: PatientProfile) -> list[DossierProfileFactResponse]:
        items: list[DossierProfileFactResponse] = []
        age = DossierService._age(profile.birth_date)
        if age is not None:
            items.append(DossierProfileFactResponse(label="Eta", value=f"{age} anni"))
        if profile.biological_sex is not None:
            items.append(
                DossierProfileFactResponse(
                    label="Sesso biologico",
                    value=profile.biological_sex.value.replace("_", " "),
                )
            )
        if profile.height_cm is not None:
            items.append(DossierProfileFactResponse(label="Altezza", value=f"{profile.height_cm:.0f} cm"))
        if profile.weight_kg is not None:
            items.append(DossierProfileFactResponse(label="Peso", value=f"{profile.weight_kg:.1f} kg"))
        bmi = DossierService._bmi(profile.height_cm, profile.weight_kg)
        if bmi is not None:
            items.append(DossierProfileFactResponse(label="BMI", value=f"{bmi:.1f}"))
        items.append(
            DossierProfileFactResponse(
                label="Fumo",
                value="Si" if profile.smoker else "No",
            )
        )
        if profile.alcohol_use is not None:
            items.append(
                DossierProfileFactResponse(
                    label="Alcol",
                    value=profile.alcohol_use.value.replace("_", " "),
                )
            )
        if profile.activity_level is not None:
            items.append(
                DossierProfileFactResponse(
                    label="Attivita",
                    value=profile.activity_level.value.replace("_", " "),
                )
            )
        if profile.occupation:
            items.append(DossierProfileFactResponse(label="Occupazione", value=profile.occupation))
        if profile.exercise_habits:
            items.append(DossierProfileFactResponse(label="Esercizio", value=profile.exercise_habits))
        if profile.sleep_pattern:
            items.append(DossierProfileFactResponse(label="Sonno", value=profile.sleep_pattern))
        if profile.functional_limitations:
            items.append(
                DossierProfileFactResponse(
                    label="Limitazioni",
                    value=profile.functional_limitations,
                )
            )
        if profile.vaccination_records:
            latest = DossierService._latest_vaccination(profile)
            if latest is not None:
                label = latest.administered_on.isoformat() if latest.administered_on else "data non indicata"
                items.append(
                    DossierProfileFactResponse(
                        label="Vaccini",
                        value=f"{len(profile.vaccination_records)} registrazioni, ultimo {latest.vaccine_name} ({label})",
                    )
                )
        active_problems = [
            item.title
            for item in profile.clinical_episodes
            if getattr(item.status, "value", item.status) in {"active", "monitoring"}
        ]
        if active_problems:
            items.append(
                DossierProfileFactResponse(
                    label="Problemi attivi",
                    value=f"{len(active_problems)} - {', '.join(active_problems[:3])}",
                )
            )
        return items

    @staticmethod
    def _latest_vaccination(profile: PatientProfile):
        if not profile.vaccination_records:
            return None
        return max(
            profile.vaccination_records,
            key=lambda item: (
                item.administered_on or date.min,
                item.created_at,
            ),
        )

    @staticmethod
    def _sorted_vaccinations(profile: PatientProfile):
        return sorted(
            profile.vaccination_records,
            key=lambda item: (
                item.administered_on or date.min,
                item.created_at,
            ),
            reverse=True,
        )

    @staticmethod
    def _sorted_clinical_episodes(profile: PatientProfile):
        return sorted(
            profile.clinical_episodes,
            key=lambda item: (
                item.onset_date or date.min,
                item.created_at,
            ),
            reverse=True,
        )

    @staticmethod
    def _profile_lines(dossier: DossierResponse) -> list[str]:
        lines = [f"{dossier.display_name}"]
        if dossier.age is not None:
            lines.append(f"Eta: {dossier.age} anni")
        if dossier.biological_sex is not None:
            lines.append(f"Sesso biologico: {dossier.biological_sex.value}")
        lines.extend(f"{fact.label}: {fact.value}" for fact in dossier.profile_facts)
        return lines

    @staticmethod
    def _provenance_lines(dossier: DossierResponse) -> list[str]:
        return [f"{fact.label}: {fact.value}" for fact in dossier.provenance_facts]

    @staticmethod
    def _emergency_lines(dossier: DossierResponse) -> list[str]:
        summary = dossier.emergency_summary
        lines = [summary.headline]
        lines.extend(summary.key_points)
        if summary.active_problems:
            lines.append("Problemi attivi: " + ", ".join(summary.active_problems))
        if summary.active_medications:
            lines.append("Farmaci attivi: " + ", ".join(summary.active_medications))
        if summary.allergies:
            lines.append("Allergie: " + ", ".join(summary.allergies))
        if summary.conditions:
            lines.append("Patologie: " + ", ".join(summary.conditions))
        if summary.open_alerts:
            lines.append("Alert aperti: " + ", ".join(summary.open_alerts))
        if summary.latest_wearable_summary:
            lines.append(f"Dati wearable: {summary.latest_wearable_summary}")
        if summary.latest_report_summary:
            lines.append(f"Report recente: {summary.latest_report_summary}")
        return lines

    @staticmethod
    def _context_lines(dossier: DossierResponse) -> list[str]:
        lines: list[str] = []
        lines.extend(
            f"Allergia: {item.allergen}{f' ({item.severity.value})' if item.severity else ''}{f' - {item.notes}' if item.notes else ''}"
            for item in dossier.allergies
        )
        lines.extend(
            f"Patologia: {item.name}{f' ({item.status.value})' if item.status else ''}{f' - {item.notes}' if item.notes else ''}"
            for item in dossier.medical_conditions
        )
        lines.extend(
            f"Familiarita: {item.relation} - {item.condition_name}{f' - {item.notes}' if item.notes else ''}"
            for item in dossier.family_history
        )
        lines.extend(
            f"Problema clinico: {item.title}{f' ({item.status.value})' if item.status else ''}"
            f"{f' - {item.summary}' if item.summary else ''}"
            for item in dossier.clinical_episodes
        )
        return lines

    @staticmethod
    def _episode_lines(dossier: DossierResponse) -> list[str]:
        lines: list[str] = []
        for item in dossier.clinical_episodes:
            parts = [item.title]
            if item.status is not None:
                parts.append(item.status.value)
            if item.onset_date is not None:
                parts.append(f"inizio {item.onset_date.isoformat()}")
            if item.resolved_date is not None:
                parts.append(f"risolto {item.resolved_date.isoformat()}")
            if item.next_review_date is not None:
                parts.append(f"follow-up {item.next_review_date.isoformat()}")
            if item.summary:
                parts.append(item.summary)
            if item.notes:
                parts.append(item.notes)
            lines.append(" - ".join(parts))
        return lines

    @staticmethod
    def _medication_lines(dossier: DossierResponse) -> list[str]:
        lines: list[str] = []
        for item in dossier.medications:
            parts = [item.name]
            if item.dosage:
                parts.append(item.dosage)
            if item.frequency:
                parts.append(item.frequency)
            if item.route:
                parts.append(item.route)
            if item.schedules:
                parts.append(DossierService._schedule_label(item.schedules[0]))
            lines.append(" - ".join(parts))
        return lines

    @staticmethod
    def _vaccination_lines(dossier: DossierResponse) -> list[str]:
        lines: list[str] = []
        for item in dossier.vaccinations:
            parts = [item.vaccine_name]
            if item.administered_on is not None:
                parts.append(f"somministrato {item.administered_on.isoformat()}")
            if item.dose_number is not None:
                parts.append(f"dose {item.dose_number}")
            if item.next_due_date is not None:
                parts.append(f"prossimo richiamo {item.next_due_date.isoformat()}")
            if item.provider_name:
                parts.append(item.provider_name)
            if item.notes:
                parts.append(item.notes)
            lines.append(" - ".join(parts))
        return lines

    @staticmethod
    def _daily_entry_lines(dossier: DossierResponse) -> list[str]:
        lines: list[str] = []
        for entry in dossier.recent_daily_entries:
            parts = [entry.entry_date.isoformat()]
            if entry.energy_level is not None:
                parts.append(f"energia {entry.energy_level}/10")
            if entry.mood_level is not None:
                parts.append(f"umore {entry.mood_level}/10")
            if entry.general_pain is not None:
                parts.append(f"dolore {entry.general_pain}/10")
            if entry.general_notes:
                parts.append(entry.general_notes)
            lines.append(" - ".join(parts))
        return lines

    @staticmethod
    def _document_lines(dossier: DossierResponse) -> list[str]:
        lines = [
            f"{item.title} ({item.document_type.value})"
            f"{f' - {item.exam_date.isoformat()}' if item.exam_date else ''}"
            f"{f' - {item.parsed_status.value}' if item.parsed_status else ''}"
            for item in dossier.recent_documents
        ]
        lines.extend(
            f"Lab: {panel.document_title} - {panel.panel_name} - {', '.join(panel.key_results)}"
            for panel in dossier.recent_lab_panels
        )
        lines.extend(
            f"Imaging: {item.document_title}"
            f"{f' - {item.exam_type}' if item.exam_type else ''}"
            f"{f' - {item.body_part}' if item.body_part else ''}"
            f"{f' - {item.impression}' if item.impression else ''}"
            for item in dossier.recent_imaging_reports
        )
        return lines

    @staticmethod
    def _device_measurement_lines(dossier: DossierResponse) -> list[str]:
        return [item.summary for item in dossier.device_measurement_summaries]

    @staticmethod
    def _insight_lines(dossier: DossierResponse) -> list[str]:
        lines = [
            f"{item.summary_type.value if hasattr(item.summary_type, 'value') else item.summary_type}: {item.content}"
            for item in dossier.recent_insights
        ]
        lines.extend(
            f"Report: {item.title} ({item.period_start.isoformat()} - {item.period_end.isoformat()})"
            for item in dossier.recent_reports
        )
        lines.extend(
            f"Alert: {item.severity.value if hasattr(item.severity, 'value') else item.severity} - {item.title}"
            for item in dossier.alerts
        )
        return lines

    @staticmethod
    def _provenance_facts(
        profile: PatientProfile,
        *,
        documents,
        reports,
        insights,
        wearables,
        device_measurement_summaries,
        recent_daily_entries,
    ) -> list[DossierProvenanceFactResponse]:
        items: list[DossierProvenanceFactResponse] = []
        profile_updated_at = getattr(profile, "updated_at", None) or getattr(profile, "created_at", None)
        if profile_updated_at is not None:
            items.append(
                DossierProvenanceFactResponse(
                    label="Profilo",
                    value=f"Aggiornato il {profile_updated_at.astimezone().strftime('%d/%m/%Y %H:%M')}",
                )
            )

        document_sources = sorted({item.source.strip() for item in documents if item.source and item.source.strip()})
        if documents:
            value = f"{len(documents)} documenti attivi"
            if document_sources:
                value += f" - fonti: {', '.join(document_sources[:3])}"
            items.append(DossierProvenanceFactResponse(label="Documenti", value=value))

        if wearables:
            platforms = sorted({item.source_platform.strip() for item in wearables if item.source_platform.strip()})
            value = f"{len(wearables)} giornate sincronizzate"
            if platforms:
                value += f" - piattaforme: {', '.join(platforms[:3])}"
            items.append(DossierProvenanceFactResponse(label="Wearable", value=value))

        if device_measurement_summaries:
            items.append(
                DossierProvenanceFactResponse(
                    label="Device clinici",
                    value=f"{len(device_measurement_summaries)} metriche sintetizzate da connettori collegati",
                )
            )

        if recent_daily_entries:
            items.append(
                DossierProvenanceFactResponse(
                    label="Diario",
                    value=f"{len(recent_daily_entries)} check-up recenti inseriti manualmente",
                )
            )

        if reports:
            items.append(
                DossierProvenanceFactResponse(
                    label="Report",
                    value=f"{len(reports)} report PDF archiviati",
                )
            )

        if insights:
            latest_insight = insights[0]
            provider = latest_insight.provider_name or "rule_based"
            model = latest_insight.model_name or "clindiary-safe-summary"
            items.append(
                DossierProvenanceFactResponse(
                    label="Insight AI",
                    value=f"{provider} / {model}",
                )
            )

        return items

    @staticmethod
    def _emergency_summary(
        profile: PatientProfile,
        *,
        recent_daily_entries,
        reports,
        alerts,
        wearables,
        clinical_episodes,
    ) -> DossierEmergencySummaryResponse:
        active_medications = [medication.name for medication in profile.medications if medication.active][:6]
        allergies = [item.allergen for item in profile.allergies][:6]
        conditions = [item.name for item in profile.conditions][:6]
        active_problems = [
            item.title
            for item in clinical_episodes
            if getattr(item.status, "value", item.status) in {"active", "monitoring"}
        ][:6]
        open_alerts = [f"{item.severity.value}: {item.title}" for item in alerts[:6]]
        key_points: list[str] = []

        if profile.allergies:
            key_points.append("Allergie e farmaci attivi sono riportati qui per una consultazione rapida.")
        if profile.conditions:
            key_points.append("Le patologie note sono incluse nel dossier clinico principale.")
        if active_problems:
            key_points.append(
                "Problemi clinici attivi: " + ", ".join(active_problems[:3]) + "."
            )
        if recent_daily_entries:
            latest_entry = recent_daily_entries[0]
            latest_entry_note = f"Ultimo check-up del {latest_entry.entry_date.isoformat()}."
            if latest_entry.general_notes:
                latest_entry_note += f" {latest_entry.general_notes}"
            key_points.append(latest_entry_note)
        if wearables:
            latest_wearable = wearables[0]
            wearable_parts = [latest_wearable.summary_date.isoformat()]
            if latest_wearable.steps_count is not None:
                wearable_parts.append(f"{latest_wearable.steps_count} passi")
            if latest_wearable.sleep_minutes is not None:
                wearable_parts.append(f"{latest_wearable.sleep_minutes:.0f} min sonno")
            key_points.append("Wearable recente: " + ", ".join(wearable_parts))
        if not key_points:
            key_points.append("Nessun dato critico aggiuntivo disponibile al momento.")

        latest_report_summary = None
        if reports:
            latest_report = reports[0]
            latest_report_summary = (
                f"{latest_report.title} ({latest_report.period_start.isoformat()} - {latest_report.period_end.isoformat()})"
            )

        latest_wearable_summary = None
        if wearables:
            latest_wearable = wearables[0]
            parts = [latest_wearable.source_platform]
            if latest_wearable.source_name:
                parts.append(latest_wearable.source_name)
            if latest_wearable.source_device_model:
                parts.append(latest_wearable.source_device_model)
            latest_wearable_summary = " - ".join(parts)

        return DossierEmergencySummaryResponse(
            generated_at=utcnow(),
            headline="Scheda emergenza ClinDiary",
            key_points=key_points,
            active_problems=active_problems,
            active_medications=active_medications,
            allergies=allergies,
            conditions=conditions,
            open_alerts=open_alerts,
            latest_wearable_summary=latest_wearable_summary,
            latest_report_summary=latest_report_summary,
        )

    @staticmethod
    def _wearable_lines(dossier: DossierResponse) -> list[str]:
        lines: list[str] = []
        for item in dossier.wearable_summaries:
            parts = [item.summary_date.isoformat()]
            if item.steps_count is not None:
                parts.append(f"{item.steps_count} passi")
            if item.sleep_minutes is not None:
                parts.append(f"{item.sleep_minutes:.0f} min sonno")
            if item.heart_rate_avg_bpm is not None:
                parts.append(f"FC media {item.heart_rate_avg_bpm:.0f} bpm")
            if item.resting_heart_rate_bpm is not None:
                parts.append(f"FC riposo {item.resting_heart_rate_bpm:.0f} bpm")
            if item.blood_oxygen_avg_pct is not None:
                parts.append(f"SpO2 {item.blood_oxygen_avg_pct:.0f}%")
            lines.append(" - ".join(parts))
        return lines

    def _device_measurement_summaries(
        self,
        patient_id,
    ) -> list[DossierDeviceMeasurementSummaryResponse]:
        measurements = self.device_repository.list_recent_measurements(
            patient_id,
            limit=80,
        )
        summaries = summarize_device_measurements(
            measurements,
            limit=self._RECENT_DEVICE_MEASUREMENT_COUNT,
        )
        return [
            DossierDeviceMeasurementSummaryResponse(
                provider_code=item.provider_code,
                provider_name=item.provider_name,
                metric_type=item.metric_type,
                metric_label=item.metric_label,
                measurement_count=item.measurement_count,
                latest_measured_at=item.latest_measured_at,
                latest_value=item.latest_value,
                trend_label=item.trend_label,
                concern_level=item.concern_level,
                concern_note=item.concern_note,
                summary=item.summary,
            )
            for item in summaries
        ]

    @staticmethod
    def _format_number(value: float | None, decimals: int = 0) -> str:
        if value is None:
            return "-"
        if decimals == 0:
            return str(int(round(value)))
        return f"{value:.{decimals}f}"

    @staticmethod
    def _schedule_label(schedule) -> str:
        parts = [schedule.scheduled_time.strftime("%H:%M")]
        if schedule.days_of_week:
            weekday_labels = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]
            days = [weekday_labels[day] for day in schedule.days_of_week if 0 <= day < len(weekday_labels)]
            if days:
                parts.append("/".join(days))
        if schedule.cycle_days_on is not None and schedule.cycle_days_off is not None:
            parts.append(f"{schedule.cycle_days_on} on/{schedule.cycle_days_off} off")
        if schedule.paused_until is not None:
            parts.append(f"pausa fino al {schedule.paused_until.isoformat()}")
        return " • ".join(parts)

    @staticmethod
    def _lab_result_label(analyte_name: str, value: str, unit: str | None) -> str:
        return f"{analyte_name}: {value}{f' {unit}' if unit else ''}"

    @staticmethod
    def _display_name(profile: PatientProfile) -> str:
        parts = [profile.first_name, profile.last_name]
        cleaned = [value.strip() for value in parts if value and value.strip()]
        return " ".join(cleaned) or "Profilo clinico"

    @staticmethod
    def _age(birth_date: date | None) -> int | None:
        if birth_date is None:
            return None
        today = date.today()
        return today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))

    @staticmethod
    def _bmi(height_cm: float | None, weight_kg: float | None) -> float | None:
        if not height_cm or not weight_kg:
            return None
        height_m = height_cm / 100
        if height_m <= 0:
            return None
        return weight_kg / (height_m * height_m)

    @staticmethod
    def _require_profile(user: User) -> PatientProfile:
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    def _require_owned_resource(self, model, patient_id, resource_id, detail: str):
        stmt = select(model).where(model.id == resource_id, model.patient_id == patient_id)
        item = self.db.scalar(stmt)
        if item is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)
        return item

    def _refresh_profile_dependent_rules(self, profile_id: UUID) -> None:
        ScreeningService(self.db)._recompute_for_profile(profile_id, emit_notifications=False)
        NotificationService(self.db).sync_patient_notifications(profile_id)
