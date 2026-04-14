from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
import unicodedata
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.ai.summary_provider import (
    SummaryGenerationInput,
    SummaryProviderOverride,
    build_summary_prompts,
    build_summary_provider,
)
from app.core.config import get_settings
from app.core.security import utcnow
from app.models.ai_summary import AiSummary
from app.models.enums import AiSummaryType, AlertStatus, DocumentContextStatus
from app.models.user import User
from app.repositories.alert_repository import AlertRepository
from app.repositories.daily_entry_repository import DailyEntryRepository
from app.repositories.device_repository import DeviceRepository
from app.repositories.document_repository import DocumentRepository
from app.repositories.insight_repository import InsightRepository
from app.repositories.medication_repository import MedicationRepository
from app.repositories.profile_repository import ProfileRepository
from app.repositories.wearable_repository import WearableRepository
from app.services.billing_service import BillingFeatureCode, BillingService
from app.services.device_measurement_summary_service import summarize_device_measurements
from app.services.profile_context import resolve_user_profile
from app.services.screening_service import ITALIAN_SCREENING_REGIONS


@dataclass(slots=True)
class TransientInsightSummary:
    id: UUID
    summary_type: AiSummaryType
    period_start: date
    period_end: date
    content: str
    provider_name: str | None
    model_name: str | None
    generated_at: datetime


class InsightService:
    _RECENT_DOCUMENT_DAYS = 90
    _MAX_CONTEXT_DOCUMENTS = 8
    _MAX_CONTEXT_LABS = 12
    _MAX_CONTEXT_IMAGING = 6
    _EXTERNAL_AI_MINIMUM_AGE = 18

    def __init__(self, db: Session) -> None:
        self.db = db
        self.insight_repository = InsightRepository(db)
        self.alert_repository = AlertRepository(db)
        self.daily_entry_repository = DailyEntryRepository(db)
        self.device_repository = DeviceRepository(db)
        self.document_repository = DocumentRepository(db)
        self.medication_repository = MedicationRepository(db)
        self.profile_repository = ProfileRepository(db)
        self.wearable_repository = WearableRepository(db)
        self.billing_service = BillingService(db)
        self.settings = get_settings()

    def get_daily_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.DAILY),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        target_date = reference_date or self._latest_entry_date(profile.id) or date.today()
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.DAILY,
            summary_label="riassunto giornaliero",
            period_start=target_date,
            period_end=target_date,
            force_refresh=False,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def regenerate_daily_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.DAILY),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        target_date = reference_date or self._latest_entry_date(profile.id) or date.today()
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.DAILY,
            summary_label="riassunto giornaliero",
            period_start=target_date,
            period_end=target_date,
            force_refresh=True,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def get_private_local_daily_summary(
        self,
        user: User,
        reference_date: date | None = None,
        *,
        model_name: str | None = None,
    ) -> TransientInsightSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.DAILY),
        )
        profile = self._require_profile(user)
        target_date = reference_date or self._latest_entry_date(profile.id) or date.today()
        payload = self._build_private_local_daily_recap_payload(
            patient_id=profile.id,
            period_start=target_date,
            period_end=target_date,
        )
        provider = build_summary_provider(
            self.settings,
            allow_external_provider=True,
            override=SummaryProviderOverride(
                provider_name="local_gemma4",
                runtime_mode="local",
                model_name=model_name,
                response_provider_name="local_gemma4",
            ),
        )
        result = provider.generate_result(payload)
        return TransientInsightSummary(
            id=uuid4(),
            summary_type=AiSummaryType.DAILY,
            period_start=target_date,
            period_end=target_date,
            content=result.content,
            provider_name=result.provider_name,
            model_name=result.model_name,
            generated_at=utcnow(),
        )

    def regenerate_private_local_daily_summary(
        self,
        user: User,
        reference_date: date | None = None,
        *,
        model_name: str | None = None,
    ) -> TransientInsightSummary:
        return self.get_private_local_daily_summary(
            user,
            reference_date,
            model_name=model_name,
        )

    def get_private_local_runtime_status(self) -> dict[str, object]:
        override = SummaryProviderOverride(
            provider_name="local_gemma4",
            runtime_mode="local",
            response_provider_name="local_gemma4",
        )
        provider = build_summary_provider(
            self.settings,
            allow_external_provider=True,
            override=override,
        )
        model_name = getattr(provider, "model_name", None)
        enabled = getattr(provider, "provider_name", None) == "local_gemma4"
        return {
            "enabled": enabled,
            "provider": "local_gemma4",
            "active_provider_label": (
                "Gemma 4 Local" if self._supports_gemma4_label(model_name) and enabled else "Modalita privata locale"
            ),
            "runtime_mode": "local",
            "backend": self.settings.local_llm_backend,
            "model_name": model_name,
            "configured_base_url_present": bool((self.settings.local_llm_base_url or "").strip()),
            "fallback_provider": "rule_based",
            "is_cloud_bypassed_for_this_request": True,
        }

    def get_on_device_daily_recap_prompt(
        self,
        user: User,
        reference_date: date | None = None,
    ) -> dict[str, object]:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.DAILY),
        )
        profile = self._require_profile(user)
        target_date = reference_date or self._latest_entry_date(profile.id) or date.today()
        payload = self._build_private_local_daily_recap_payload(
            patient_id=profile.id,
            period_start=target_date,
            period_end=target_date,
        )
        system_prompt, user_prompt = build_summary_prompts(payload)
        return {
            "summary_type": AiSummaryType.DAILY,
            "period_start": target_date,
            "period_end": target_date,
            "system_prompt": system_prompt,
            "user_prompt": user_prompt,
            "provider_name": "on_device_litertlm",
            "suggested_model_family": "Gemma 4",
            "is_cloud_bypassed_for_this_request": True,
        }

    def get_weekly_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.WEEKLY),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        period_end = reference_date or self._latest_entry_date(profile.id) or date.today()
        period_start = period_end - timedelta(days=6)
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.WEEKLY,
            summary_label="riassunto settimanale",
            period_start=period_start,
            period_end=period_end,
            force_refresh=False,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def regenerate_weekly_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.WEEKLY),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        period_end = reference_date or self._latest_entry_date(profile.id) or date.today()
        period_start = period_end - timedelta(days=6)
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.WEEKLY,
            summary_label="riassunto settimanale",
            period_start=period_start,
            period_end=period_end,
            force_refresh=True,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def get_monthly_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.MONTHLY),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        period_end = reference_date or self._latest_entry_date(profile.id) or date.today()
        period_start = period_end - timedelta(days=29)
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.MONTHLY,
            summary_label="riassunto mensile",
            period_start=period_start,
            period_end=period_end,
            force_refresh=False,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def regenerate_monthly_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.MONTHLY),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        period_end = reference_date or self._latest_entry_date(profile.id) or date.today()
        period_start = period_end - timedelta(days=29)
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.MONTHLY,
            summary_label="riassunto mensile",
            period_start=period_start,
            period_end=period_end,
            force_refresh=True,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def get_pre_visit_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.PRE_VISIT),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        period_end = reference_date or self._latest_entry_date(profile.id) or date.today()
        period_start = period_end - timedelta(days=29)
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.PRE_VISIT,
            summary_label="riassunto pre-visita",
            period_start=period_start,
            period_end=period_end,
            force_refresh=False,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def regenerate_pre_visit_summary(self, user: User, reference_date: date | None = None) -> AiSummary:
        self.billing_service.require_feature(
            user,
            self.billing_service.summary_feature_code(AiSummaryType.PRE_VISIT),
        )
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        period_end = reference_date or self._latest_entry_date(profile.id) or date.today()
        period_start = period_end - timedelta(days=29)
        return self._upsert_summary_by_patient(
            patient_id=profile.id,
            summary_type=AiSummaryType.PRE_VISIT,
            summary_label="riassunto pre-visita",
            period_start=period_start,
            period_end=period_end,
            force_refresh=True,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )

    def build_transient_summary(
        self,
        user: User,
        *,
        summary_label: str,
        period_start: date,
        period_end: date,
    ) -> str:
        self.billing_service.require_feature(user, BillingFeatureCode.AI_REPORT_GENERATION)
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        payload = self._build_summary_payload(
            patient_id=profile.id,
            summary_type="ad_hoc",
            summary_label=summary_label,
            period_start=period_start,
            period_end=period_end,
        )
        provider = build_summary_provider(
            self.settings,
            allow_external_provider=self._allow_external_provider(profile, onboarding),
        )
        return provider.generate(payload)

    def sync_due_summaries(
        self,
        summary_type: AiSummaryType,
        *,
        reference_date: date | None = None,
    ) -> dict[str, int | str]:
        anchor_date = reference_date or date.today()
        processed = 0
        generated = 0
        skipped = 0

        for patient_id in self.profile_repository.list_patient_ids():
            processed += 1
            period_start, period_end, label = self._compute_period(summary_type, anchor_date)
            if not self.billing_service.has_feature_for_patient(
                patient_id,
                self.billing_service.summary_feature_code(summary_type),
            ):
                skipped += 1
                continue
            if not self._period_has_relevant_data(patient_id, period_start, period_end):
                skipped += 1
                continue

            self._upsert_summary_by_patient(
                patient_id=patient_id,
                summary_type=summary_type,
                summary_label=label,
                period_start=period_start,
                period_end=period_end,
                force_refresh=False,
                allow_external_provider=self._allow_external_provider_for_patient(patient_id),
            )
            generated += 1

        return {
            "summary_type": summary_type.value,
            "reference_date": anchor_date.isoformat(),
            "processed": processed,
            "generated": generated,
            "skipped": skipped,
        }

    def _upsert_summary_by_patient(
        self,
        *,
        patient_id: UUID,
        summary_type: AiSummaryType,
        summary_label: str,
        period_start: date,
        period_end: date,
        force_refresh: bool,
        allow_external_provider: bool,
    ) -> AiSummary:
        summary = self.insight_repository.get_by_period(
            patient_id=patient_id,
            summary_type=summary_type,
            period_start=period_start,
            period_end=period_end,
        )
        if summary is not None and not force_refresh:
            return summary

        payload = self._build_summary_payload(
            patient_id=patient_id,
            summary_type=summary_type.value,
            summary_label=summary_label,
            period_start=period_start,
            period_end=period_end,
        )
        provider = build_summary_provider(
            self.settings,
            allow_external_provider=allow_external_provider,
        )
        result = provider.generate_result(payload)
        if summary is None:
            summary = AiSummary(
                patient_id=patient_id,
                summary_type=summary_type,
                period_start=period_start,
                period_end=period_end,
                content=result.content,
                provider_name=result.provider_name,
                model_name=result.model_name,
            )
            self.insight_repository.add(summary)
        else:
            summary.content = result.content
            summary.provider_name = result.provider_name
            summary.model_name = result.model_name
            summary.generated_at = utcnow()

        self.db.commit()
        self.db.refresh(summary)
        return summary

    def _build_private_local_daily_recap_payload(
        self,
        *,
        patient_id: UUID,
        period_start: date,
        period_end: date,
    ) -> SummaryGenerationInput:
        payload = self._build_summary_payload(
            patient_id=patient_id,
            summary_type="daily",
            summary_label="riassunto giornaliero privato locale",
            period_start=period_start,
            period_end=period_end,
        )
        return self._minimize_private_local_daily_payload(payload)

    def can_access_summary(self, user: User, summary_type: AiSummaryType) -> bool:
        return self.billing_service.has_feature(
            user,
            self.billing_service.summary_feature_code(summary_type),
        )

    def _build_summary_payload(
        self,
        *,
        patient_id: UUID,
        summary_type: str,
        summary_label: str,
        period_start: date,
        period_end: date,
    ) -> SummaryGenerationInput:
        profile = self.profile_repository.get_profile_by_patient_id(patient_id)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

        entries = self.daily_entry_repository.list_for_patient_between(patient_id, period_start, period_end)
        entries = sorted(entries, key=lambda item: (item.entry_date, item.created_at))
        alerts = self.alert_repository.list_for_patient(patient_id, status=AlertStatus.OPEN)
        all_documents = self.document_repository.list_for_patient_with_details(
            patient_id,
            context_status=DocumentContextStatus.ACTIVE,
        )
        recent_documents = self._select_recent_documents(all_documents, period_end)
        medication_logs = self.medication_repository.list_logs_for_patient_between(
            patient_id,
            start_at=datetime.combine(period_start, time.min, tzinfo=timezone.utc),
            end_at=datetime.combine(period_end, time.max, tzinfo=timezone.utc),
        )
        device_measurements = self.device_repository.list_for_patient_between(
            patient_id,
            start_at=datetime.combine(period_start, time.min, tzinfo=timezone.utc),
            end_at=datetime.combine(period_end, time.max, tzinfo=timezone.utc),
        )
        wearable_summaries = self.wearable_repository.list_for_patient_between(
            patient_id,
            period_start,
            period_end,
        )
        clinical_episodes = self._format_clinical_episodes(profile)
        prior_daily_summaries = self._format_prior_daily_summaries(
            patient_id=patient_id,
            period_start=period_start,
        )

        symptom_counter = Counter(
            symptom.symptom_code.replace("_", " ")
            for entry in entries
            for symptom in entry.symptoms
        )
        observations: list[str] = []
        follow_up_reasons: list[str] = []

        if entries:
            energy_values = [entry.energy_level for entry in entries if entry.energy_level is not None]
            mood_values = [entry.mood_level for entry in entries if entry.mood_level is not None]
            pain_values = [entry.general_pain for entry in entries if entry.general_pain is not None]
            stress_values = [entry.stress_level for entry in entries if entry.stress_level is not None]
            sleep_values = [entry.sleep_quality for entry in entries if entry.sleep_quality is not None]

            for values, label in (
                (energy_values, "energia"),
                (mood_values, "umore"),
                (pain_values, "dolore"),
                (stress_values, "stress"),
                (sleep_values, "qualita del sonno"),
            ):
                if values:
                    observations.append(f"{label.capitalize()} media {sum(values) / len(values):.1f}/10.")

            top_symptoms = symptom_counter.most_common(4)
            if top_symptoms:
                observations.append(
                    "Sintomi piu frequenti: "
                    + ", ".join(f"{label} ({count})" for label, count in top_symptoms)
                    + "."
                )

            low_sleep_and_low_energy = sum(
                1
                for entry in entries
                if (entry.sleep_quality or 10) <= 4 and (entry.energy_level or 10) <= 4
            )
            if low_sleep_and_low_energy >= 2:
                observations.append(
                    "Piu giornate mostrano energia bassa insieme a sonno percepito come scarso."
                )
                follow_up_reasons.append(
                    "Energia bassa e sonno scarso compaiono in piu giornate: utile segnalarlo al medico se il trend continua."
                )

            high_stress_and_pain = sum(
                1
                for entry in entries
                if (entry.stress_level or 0) >= 7 and (entry.general_pain or 0) >= 6
            )
            if high_stress_and_pain >= 2:
                observations.append(
                    "Stress elevato e dolore piu intenso compaiono insieme in piu rilevazioni."
                )
                follow_up_reasons.append(
                    "Stress elevato e dolore intenso ricorrono nello stesso periodo: puo essere utile discuterne con il medico."
                )

            high_symptom_burden = any(
                symptom.severity is not None and symptom.severity >= 7
                for entry in entries
                for symptom in entry.symptoms
            ) or any((entry.general_pain or 0) >= 7 for entry in entries)
            if high_symptom_burden:
                follow_up_reasons.append(
                    "Nel periodo risultano sintomi o dolore auto-riferiti ad alta intensita: non ignorarli se persistono o peggiorano."
                )
        else:
            observations.append("Nel periodo selezionato non risultano check-up completi da sintetizzare.")

        abnormal_lab_count = 0
        recent_lab_results: list[str] = []
        recent_imaging_reports: list[str] = []
        recent_document_lines: list[str] = []
        for document in recent_documents:
            doc_date = self._document_date(document)
            recent_document_lines.append(
                f"{document.title} ({document.document_type.value}) del {doc_date.isoformat()} stato {document.parsed_status.value}"
            )

            for panel in document.lab_panels:
                for result in panel.results:
                    if len(recent_lab_results) >= self._MAX_CONTEXT_LABS:
                        break
                    range_part = ""
                    if result.ref_min is not None or result.ref_max is not None:
                        range_part = f" range {result.ref_min or '-'}-{result.ref_max or '-'}"
                    abnormal_part = " fuori range" if result.abnormal_flag else ""
                    recent_lab_results.append(
                        f"{doc_date.isoformat()} - {panel.panel_name}: {result.analyte_name} {result.value}"
                        f"{f' {result.unit}' if result.unit else ''}{range_part}{abnormal_part}"
                    )
                    if result.abnormal_flag:
                        abnormal_lab_count += 1
                if len(recent_lab_results) >= self._MAX_CONTEXT_LABS:
                    break

            for imaging in document.imaging_reports:
                if len(recent_imaging_reports) >= self._MAX_CONTEXT_IMAGING:
                    break
                descriptor = imaging.impression or imaging.report_text[:220]
                recent_imaging_reports.append(
                    f"{doc_date.isoformat()} - {imaging.exam_type or document.title}"
                    f"{f' {imaging.body_part}' if imaging.body_part else ''}: {descriptor}"
                )

        if abnormal_lab_count:
            observations.append(
                f"Sono presenti {abnormal_lab_count} risultati laboratoristici recenti gia marcati come fuori range dal parser."
            )
            follow_up_reasons.append(
                "Sono presenti esami recenti con valori marcati fuori range dal parser: portali al medico per un inquadramento clinico."
            )

        if alerts:
            follow_up_reasons.append(
                "Sono presenti alert deterministici aperti: il riepilogo va discusso con il medico senza attendere interpretazioni automatiche."
            )

        if medication_logs:
            skipped_or_missed = sum(
                1 for log in medication_logs if log.status.value in {"skipped", "missed"}
            )
            if skipped_or_missed:
                observations.append(
                    f"Aderenza terapeutica non completa nel periodo: {skipped_or_missed} registrazioni tra dose saltata o mancata."
                )
                follow_up_reasons.append(
                    "Se l'aderenza terapeutica resta difficile, puo essere utile parlarne con il medico o con il team che segue la terapia."
                )

        if clinical_episodes:
            active_problem_count = sum(
                1
                for item in profile.clinical_episodes
                if self._is_active_episode(item)
            )
            observations.append(
                f"Problemi/episodi clinici strutturati disponibili: {len(clinical_episodes)}"
                + (f", di cui {active_problem_count} attivi o in monitoraggio." if active_problem_count else ".")
            )

        wearable_lines: list[str] = []
        if wearable_summaries:
            steps_values = [float(item.steps_count) for item in wearable_summaries if item.steps_count is not None]
            sleep_values = [item.sleep_minutes for item in wearable_summaries if item.sleep_minutes is not None]
            resting_hr_values = [
                item.resting_heart_rate_bpm
                for item in wearable_summaries
                if item.resting_heart_rate_bpm is not None
            ]
            blood_oxygen_values = [
                item.blood_oxygen_avg_pct
                for item in wearable_summaries
                if item.blood_oxygen_avg_pct is not None
            ]

            if steps_values:
                observations.append(
                    f"Dati wearable: media passi {sum(steps_values) / len(steps_values):.0f} al giorno."
                )
            if sleep_values:
                observations.append(
                    f"Dati wearable: sonno medio {sum(sleep_values) / len(sleep_values) / 60:.1f} ore per notte."
                )
            if resting_hr_values:
                observations.append(
                    f"Dati wearable: frequenza cardiaca a riposo media {sum(resting_hr_values) / len(resting_hr_values):.0f} bpm."
                )
            if blood_oxygen_values:
                observations.append(
                    f"Dati wearable: saturazione media registrata {sum(blood_oxygen_values) / len(blood_oxygen_values):.0f}%."
                )

            very_low_sleep_days = sum(
                1
                for item in wearable_summaries
                if item.sleep_minutes is not None and item.sleep_minutes < 240
            )
            if very_low_sleep_days >= 2:
                follow_up_reasons.append(
                    "I dati wearable mostrano piu giornate con sonno molto ridotto: se il pattern continua, puo essere utile segnalarlo al medico."
                )

            for item in wearable_summaries[-10:]:
                wearable_parts = []
                if item.steps_count is not None:
                    wearable_parts.append(f"{item.steps_count} passi")
                if item.sleep_minutes is not None:
                    wearable_parts.append(f"sonno {item.sleep_minutes / 60:.1f}h")
                if item.heart_rate_avg_bpm is not None:
                    wearable_parts.append(f"FC media {item.heart_rate_avg_bpm:.0f} bpm")
                if item.resting_heart_rate_bpm is not None:
                    wearable_parts.append(f"FC riposo {item.resting_heart_rate_bpm:.0f} bpm")
                if item.blood_oxygen_avg_pct is not None:
                    wearable_parts.append(f"SpO2 {item.blood_oxygen_avg_pct:.0f}%")
                if item.exercise_minutes is not None:
                    wearable_parts.append(f"esercizio {item.exercise_minutes:.0f} min")
                if wearable_parts:
                    wearable_lines.append(
                        f"{item.summary_date.isoformat()} ({item.source_platform}): " + ", ".join(wearable_parts)
                    )

        device_measurement_summaries = summarize_device_measurements(device_measurements, limit=10)
        device_measurement_lines = [item.ai_summary for item in device_measurement_summaries]
        if device_measurement_lines:
            observations.append(
                f"Sono disponibili {len(device_measurements)} misure da dispositivi clinici collegati nel periodo."
            )
            concern_notes = [
                item.concern_note
                for item in device_measurement_summaries
                if item.concern_note
            ]
            for note in concern_notes[:3]:
                if note not in observations:
                    observations.append(note)
                if note not in follow_up_reasons:
                    follow_up_reasons.append(note)

        data_considered = [
            f"{len(entries)} check-up",
            f"{sum(len(entry.symptoms) for entry in entries)} sintomi",
            f"{sum(len(entry.vitals) for entry in entries)} parametri vitali",
            f"{len(medication_logs)} log terapia",
            f"{len(wearable_summaries)} giornate wearable",
            f"{len(device_measurements)} misure da dispositivi clinici",
            f"{len(recent_documents)} documenti recenti nel contesto",
            f"{len(prior_daily_summaries)} recap giornalieri precedenti",
            f"{len(clinical_episodes)} problemi/episodi clinici",
            f"{len(alerts)} alert aperti",
        ]

        missing_data: list[str] = []
        if profile.birth_date is None:
            missing_data.append("Data di nascita non presente nel profilo.")
        if not entries:
            missing_data.append("Nessun check-up completo registrato nel periodo selezionato.")
        if not recent_lab_results and not recent_imaging_reports:
            missing_data.append("Nessun esame strutturato recente disponibile nel contesto analizzato.")
        if not wearable_summaries:
            missing_data.append("Nessun dato wearable/smartwatch importato nel periodo.")
        if not device_measurements:
            missing_data.append("Nessuna misura da dispositivi clinici collegati importata nel periodo.")

        payload = SummaryGenerationInput(
            summary_type=summary_type,
            summary_label=summary_label,
            period_start=period_start,
            period_end=period_end,
            data_considered=data_considered,
            patient_snapshot=self._patient_snapshot(profile),
            active_conditions=self._format_conditions(profile),
            allergies=self._format_allergies(profile),
            family_history=self._format_family_history(profile),
            medications=self._format_medications(profile),
            medication_adherence=self._format_medication_logs(medication_logs),
            wearable_daily_summaries=wearable_lines,
            device_measurement_summaries=device_measurement_lines,
            prior_daily_summaries=prior_daily_summaries,
            clinical_episodes=clinical_episodes,
            journal_entries=[self._serialize_entry(entry) for entry in entries],
            observations=observations,
            recent_lab_results=recent_lab_results,
            recent_imaging_reports=recent_imaging_reports,
            recent_documents=recent_document_lines,
            open_alerts=[f"{alert.severity.value}: {alert.title}" for alert in alerts[:5]],
            follow_up_reasons=follow_up_reasons,
            missing_data=missing_data,
        )
        return self._minimize_payload(payload)

    def _period_has_relevant_data(self, patient_id: UUID, period_start: date, period_end: date) -> bool:
        entries = self.daily_entry_repository.list_for_patient_between(patient_id, period_start, period_end)
        if entries:
            return True

        logs = self.medication_repository.list_logs_for_patient_between(
            patient_id,
            start_at=datetime.combine(period_start, time.min, tzinfo=timezone.utc),
            end_at=datetime.combine(period_end, time.max, tzinfo=timezone.utc),
        )
        if logs:
            return True

        device_measurements = self.device_repository.list_for_patient_between(
            patient_id,
            start_at=datetime.combine(period_start, time.min, tzinfo=timezone.utc),
            end_at=datetime.combine(period_end, time.max, tzinfo=timezone.utc),
            limit=1,
        )
        if device_measurements:
            return True

        wearable_summaries = self.wearable_repository.list_for_patient_between(
            patient_id,
            period_start,
            period_end,
        )
        if wearable_summaries:
            return True

        documents = self.document_repository.list_for_patient(
            patient_id,
            context_status=DocumentContextStatus.ACTIVE,
        )
        return any(period_start <= self._document_date(document) <= period_end for document in documents)

    def _select_recent_documents(self, documents: list, period_end: date) -> list:
        context_start = period_end - timedelta(days=self._RECENT_DOCUMENT_DAYS - 1)
        return [
            document
            for document in documents
            if context_start <= self._document_date(document) <= period_end
        ][: self._MAX_CONTEXT_DOCUMENTS]

    @staticmethod
    def _patient_snapshot(profile) -> list[str]:
        snapshot: list[str] = []
        demographics: list[str] = []
        if profile.birth_date is not None:
            demographics.append(f"{InsightService._age_from_birth_date(profile.birth_date)} anni")
        if profile.biological_sex is not None:
            demographics.append(f"sesso biologico {profile.biological_sex.value}")
        if demographics:
            snapshot.append("Paziente: " + ", ".join(demographics))

        body_data: list[str] = []
        if profile.height_cm is not None:
            body_data.append(f"altezza {profile.height_cm:.0f} cm")
        if profile.weight_kg is not None:
            body_data.append(f"peso {profile.weight_kg:.1f} kg")
        if body_data:
            snapshot.append(", ".join(body_data))

        lifestyle: list[str] = []
        lifestyle.append("fumatore" if profile.smoker else "non fumatore")
        if profile.alcohol_use is not None:
            lifestyle.append(f"alcol {profile.alcohol_use.value}")
        if profile.activity_level is not None:
            lifestyle.append(f"attivita {profile.activity_level.value}")
        snapshot.append(", ".join(lifestyle))
        if profile.exercise_habits:
            snapshot.append(f"Sport/attivita abituale: {profile.exercise_habits}")
        if profile.sleep_pattern:
            snapshot.append(f"Sonno abituale: {profile.sleep_pattern}")
        if profile.occupation:
            snapshot.append(f"Contesto lavorativo: {profile.occupation}")
        region_code = InsightService._region_code_value(profile.region_code) or "IT"
        if region_code is not None:
            region_name = next(
                (
                    name
                    for code, name in ITALIAN_SCREENING_REGIONS
                    if code.upper() == region_code.upper()
                ),
                region_code,
            )
            snapshot.append(f"Regione screening/prevenzione: {region_name} ({region_code})")
        if profile.symptom_triggers:
            snapshot.append(f"Trigger noti dei sintomi: {profile.symptom_triggers}")
        if profile.functional_limitations:
            snapshot.append(f"Limitazioni funzionali riferite: {profile.functional_limitations}")
        vaccination_lines = InsightService._format_vaccinations(profile)
        if vaccination_lines:
            snapshot.append(f"Storico vaccinale: {'; '.join(vaccination_lines[:3])}")
        episode_lines = InsightService._format_clinical_episodes(profile)
        if episode_lines:
            snapshot.append(f"Problemi/episodi clinici: {'; '.join(episode_lines[:3])}")
        return snapshot

    def _format_prior_daily_summaries(
        self,
        *,
        patient_id: UUID,
        period_start: date,
    ) -> list[str]:
        context_end = period_start - timedelta(days=1)
        context_start = period_start - timedelta(days=15)
        if context_end < context_start:
            return []

        prior_summaries = self.insight_repository.list_between(
            patient_id=patient_id,
            summary_type=AiSummaryType.DAILY,
            start_date=context_start,
            end_date=context_end,
        )
        items: list[str] = []
        for summary in prior_summaries[-15:]:
            compact = " ".join(summary.content.split())
            if len(compact) > 700:
                compact = compact[:697].rstrip() + "..."
            items.append(
                f"{summary.period_start.isoformat()} (generato {summary.generated_at.date().isoformat()}): {compact}"
            )
        return items

    @staticmethod
    def _format_conditions(profile) -> list[str]:
        return [
            (
                f"{condition.name}"
                f"{f' ({condition.status.value})' if condition.status else ''}"
                f"{f' dal {condition.diagnosis_date.isoformat()}' if condition.diagnosis_date else ''}"
            )
            for condition in profile.conditions
        ]

    @staticmethod
    def _format_allergies(profile) -> list[str]:
        return [
            (
                f"{allergy.allergen}"
                f"{f' ({allergy.severity.value})' if allergy.severity else ''}"
                f"{f' - {allergy.notes}' if allergy.notes else ''}"
            )
            for allergy in profile.allergies
        ]

    @staticmethod
    def _format_family_history(profile) -> list[str]:
        return [
            (
                f"{item.relation}: {item.condition_name}"
                f"{f' - {item.notes}' if item.notes else ''}"
            )
            for item in profile.family_history_entries
        ]

    @staticmethod
    def _region_code_value(region_code) -> str | None:
        if region_code is None:
            return None
        value = getattr(region_code, "value", region_code)
        text = str(value).strip()
        return text.upper() if text else None

    @staticmethod
    def _format_vaccinations(profile) -> list[str]:
        items = sorted(
            profile.vaccination_records,
            key=lambda item: (
                item.administered_on or date.min,
                item.created_at,
            ),
            reverse=True,
        )
        return [
            (
                f"{item.vaccine_name}"
                f"{f' somministrato il {item.administered_on.isoformat()}' if item.administered_on else ''}"
                f"{f' dose {item.dose_number}' if item.dose_number is not None else ''}"
                f"{f' richiamo {item.next_due_date.isoformat()}' if item.next_due_date else ''}"
                f"{f' - {item.provider_name}' if item.provider_name else ''}"
                f"{f' - {item.notes}' if item.notes else ''}"
            )
            for item in items
        ]

    @staticmethod
    def _format_clinical_episodes(profile) -> list[str]:
        items = sorted(
            profile.clinical_episodes,
            key=lambda item: (
                item.onset_date or date.min,
                item.created_at,
            ),
            reverse=True,
        )
        return [
            (
                f"{item.title}"
                f"{f' ({item.status.value})' if item.status else ''}"
                f"{f' dal {item.onset_date.isoformat()}' if item.onset_date else ''}"
                f"{f' - follow-up {item.next_review_date.isoformat()}' if item.next_review_date else ''}"
                f"{f' - {item.summary}' if item.summary else ''}"
            )
            for item in items
        ]

    @staticmethod
    def _is_active_episode(item) -> bool:
        return getattr(item.status, "value", item.status) in {"active", "monitoring"}

    @staticmethod
    def _format_medications(profile) -> list[str]:
        items: list[str] = []
        for medication in profile.medications:
            if not medication.active:
                continue
            schedule_times = [
                schedule.scheduled_time.strftime("%H:%M")
                for schedule in medication.schedules
                if schedule.active
            ]
            items.append(
                " ".join(
                    part
                    for part in [
                        medication.name,
                        medication.dosage,
                        medication.frequency,
                        medication.route,
                        f"orari {', '.join(schedule_times)}" if schedule_times else None,
                    ]
                    if part
                )
            )
        return items

    @staticmethod
    def _format_medication_logs(logs) -> list[str]:
        return [
            (
                f"{log.scheduled_at.date().isoformat()} {log.scheduled_at.strftime('%H:%M')} - "
                f"{log.medication.name}: {log.status.value}"
                f"{f' ({log.notes})' if log.notes else ''}"
            )
            for log in logs[:8]
        ]

    @staticmethod
    def _format_number(value: float | None, decimals: int = 0) -> str:
        if value is None:
            return "-"
        if decimals == 0:
            return str(int(round(value)))
        return f"{value:.{decimals}f}"

    @staticmethod
    def _serialize_entry(entry) -> dict[str, object]:
        general_note_tags = InsightService._note_tags(entry.general_notes)
        general_note_summary = InsightService._compact_note_summary(
            entry.general_notes,
            general_note_tags,
        )
        return {
            "date": entry.entry_date.isoformat(),
            "sleep_hours": entry.sleep_hours,
            "sleep_quality": entry.sleep_quality,
            "energy_level": entry.energy_level,
            "mood_level": entry.mood_level,
            "stress_level": entry.stress_level,
            "appetite_level": entry.appetite_level,
            "hydration_level": entry.hydration_level,
            "general_pain": entry.general_pain,
            "general_notes": general_note_summary,
            "general_note_tags": general_note_tags,
            "symptoms": [
                InsightService._serialize_symptom(symptom)
                for symptom in entry.symptoms
            ],
            "vitals": [
                f"{vital.type} {vital.value}{f' {vital.unit}' if vital.unit else ''}"
                for vital in entry.vitals
            ],
        }

    @staticmethod
    def _serialize_symptom(symptom) -> dict[str, object]:
        metadata_digest = InsightService._symptom_metadata_digest(symptom.metadata_json)
        payload: dict[str, object] = {
            "code": symptom.symptom_code,
            "severity": symptom.severity,
            "duration_minutes": symptom.duration_minutes,
            "body_location": symptom.body_location,
        }
        if metadata_digest["metadata_flags"]:
            payload["metadata_flags"] = metadata_digest["metadata_flags"]
        if metadata_digest["note_tags"]:
            payload["note_tags"] = metadata_digest["note_tags"]
        if metadata_digest["note_excerpt"]:
            payload["note_excerpt"] = metadata_digest["note_excerpt"]
        return payload

    @staticmethod
    def _symptom_metadata_digest(metadata: dict | None) -> dict[str, object]:
        note_text = None
        if isinstance(metadata, dict):
            for key in ("notes", "note", "description", "comment", "text", "associated_symptoms"):
                note_text = InsightService._normalize_text(metadata.get(key))
                if note_text:
                    break

        note_tags = InsightService._note_tags(note_text)
        metadata_flags: list[str] = []
        if isinstance(metadata, dict):
            temperature = metadata.get("temperature_c")
            if isinstance(temperature, (int, float)):
                metadata_flags.append(
                    f"temperature_c={InsightService._format_number(float(temperature), 1)}"
                )

            duration_days = metadata.get("duration_days")
            if isinstance(duration_days, (int, float)):
                metadata_flags.append(f"duration_days={int(round(float(duration_days)))}")
            elif isinstance(duration_days, str) and duration_days.strip():
                metadata_flags.append(f"duration_days={duration_days.strip()}")

            for key in ("with_nausea", "with_aura", "vomiting"):
                if metadata.get(key) is True:
                    metadata_flags.append(f"{key}=true")

        note_excerpt = None
        if note_text and not note_tags:
            note_excerpt = InsightService._truncate_text(note_text, 80)

        return {
            "note_tags": note_tags,
            "metadata_flags": metadata_flags,
            "note_excerpt": note_excerpt,
        }

    @staticmethod
    def _compact_note_summary(text: str | None, note_tags: list[str]) -> str | None:
        normalized = InsightService._normalize_text(text)
        if not normalized:
            if note_tags:
                return f"tags: {', '.join(note_tags[:4])}"
            return None
        if note_tags:
            return f"tags: {', '.join(note_tags[:4])}"
        return InsightService._truncate_text(normalized, 120)

    @staticmethod
    def _note_tags(text: str | None) -> list[str]:
        folded = InsightService._fold_text(text)
        if not folded:
            return []

        tags: list[str] = []

        def add(tag: str) -> None:
            if tag not in tags:
                tags.append(tag)

        tag_patterns = (
            ("stress_lavoro", ("stress", "lavor", "uffic", "turno", "riunion", "scaden")),
            ("umore_basso", ("giu di morale", "trist", "umore", "ansi", "preoccup", "demoral")),
            ("sonno_scarso", ("sonn", "dorm", "insonn", "risvegli", "riposo")),
            ("cefalea", ("cefale", "mal di testa", "headache")),
            ("tosse", ("toss", "cough")),
            ("febbre", ("febbr", "temperatur")),
            ("nausea", ("nause", "vomit")),
            ("dolore", ("dolor", "pain")),
            ("digestivo", ("addom", "stomac", "gastr", "diarr", "intestin")),
            ("respiratorio", ("respir", "fiat", "dispn", "saturaz")),
        )

        for tag, fragments in tag_patterns:
            if any(fragment in folded for fragment in fragments):
                add(tag)
            if len(tags) >= 4:
                break

        return tags

    @staticmethod
    def _normalize_text(value) -> str | None:
        if value is None:
            return None
        text = " ".join(str(value).split()).strip()
        return text or None

    @staticmethod
    def _fold_text(text: str | None) -> str:
        if not text:
            return ""
        normalized = unicodedata.normalize("NFKD", text)
        folded = "".join(char for char in normalized if not unicodedata.combining(char))
        return folded.lower()

    @staticmethod
    def _truncate_text(text: str, max_length: int) -> str:
        compact = " ".join(text.split()).strip()
        if len(compact) <= max_length:
            return compact
        return compact[: max_length - 3].rstrip() + "..."

    @staticmethod
    def _document_date(document) -> date:
        return document.exam_date or document.upload_date.date()

    @staticmethod
    def _age_from_birth_date(birth_date: date) -> int:
        today = date.today()
        years = today.year - birth_date.year
        if (today.month, today.day) < (birth_date.month, birth_date.day):
            years -= 1
        return years

    def _latest_entry_date(self, patient_id: UUID):
        entries = self.daily_entry_repository.list_for_patient(patient_id)
        if not entries:
            return None
        return entries[0].entry_date

    @staticmethod
    def _compute_period(summary_type: AiSummaryType, anchor_date: date) -> tuple[date, date, str]:
        if summary_type == AiSummaryType.DAILY:
            return anchor_date, anchor_date, "riassunto giornaliero"
        if summary_type == AiSummaryType.WEEKLY:
            return anchor_date - timedelta(days=6), anchor_date, "riassunto settimanale"
        if summary_type == AiSummaryType.MONTHLY:
            return anchor_date - timedelta(days=29), anchor_date, "riassunto mensile"
        return anchor_date - timedelta(days=29), anchor_date, "riassunto pre-visita"

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    def _require_onboarding(self, user: User):
        if user.onboarding_status is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Onboarding not found")
        return user.onboarding_status

    def _allow_external_provider_for_patient(self, patient_id: UUID) -> bool:
        profile = self.profile_repository.get_profile_by_patient_id(patient_id)
        if profile is None or profile.user is None or profile.user.onboarding_status is None:
            return False
        return self._allow_external_provider(profile, profile.user.onboarding_status)

    def _allow_external_provider(self, profile, onboarding) -> bool:
        if not getattr(onboarding, "ai_external_consent", False):
            return False
        birth_date = getattr(profile, "birth_date", None)
        if birth_date is None:
            return True
        return self._age_from_birth_date(birth_date) >= self._EXTERNAL_AI_MINIMUM_AGE

    def _minimize_payload(self, payload: SummaryGenerationInput) -> SummaryGenerationInput:
        normalized = (payload.summary_type or "").strip().lower().replace("-", "_")
        limits = {
            "daily": {
                "patient_snapshot": 7,
                "active_conditions": 5,
                "allergies": 4,
                "family_history": 3,
                "medications": 5,
                "medication_adherence": 4,
                "wearable_daily_summaries": 3,
                "device_measurement_summaries": 4,
                "journal_entries": 2,
                "observations": 8,
                "recent_lab_results": 5,
                "recent_imaging_reports": 2,
                "recent_documents": 3,
                "prior_daily_summaries": 3,
                "clinical_episodes": 4,
                "open_alerts": 4,
                "follow_up_reasons": 5,
                "missing_data": 4,
            },
            "weekly": {
                "patient_snapshot": 8,
                "active_conditions": 6,
                "allergies": 4,
                "family_history": 4,
                "medications": 6,
                "medication_adherence": 6,
                "wearable_daily_summaries": 6,
                "device_measurement_summaries": 6,
                "journal_entries": 5,
                "observations": 10,
                "recent_lab_results": 8,
                "recent_imaging_reports": 3,
                "recent_documents": 5,
                "prior_daily_summaries": 5,
                "clinical_episodes": 5,
                "open_alerts": 5,
                "follow_up_reasons": 6,
                "missing_data": 4,
            },
            "monthly": {
                "patient_snapshot": 10,
                "active_conditions": 8,
                "allergies": 5,
                "family_history": 5,
                "medications": 8,
                "medication_adherence": 8,
                "wearable_daily_summaries": 10,
                "device_measurement_summaries": 8,
                "journal_entries": 10,
                "observations": 12,
                "recent_lab_results": 10,
                "recent_imaging_reports": 5,
                "recent_documents": 6,
                "prior_daily_summaries": 8,
                "clinical_episodes": 6,
                "open_alerts": 5,
                "follow_up_reasons": 8,
                "missing_data": 5,
            },
            "pre_visit": {
                "patient_snapshot": 10,
                "active_conditions": 8,
                "allergies": 5,
                "family_history": 5,
                "medications": 8,
                "medication_adherence": 8,
                "wearable_daily_summaries": 10,
                "device_measurement_summaries": 8,
                "journal_entries": 10,
                "observations": 12,
                "recent_lab_results": 10,
                "recent_imaging_reports": 5,
                "recent_documents": 6,
                "prior_daily_summaries": 8,
                "clinical_episodes": 6,
                "open_alerts": 5,
                "follow_up_reasons": 8,
                "missing_data": 5,
            },
            "ad_hoc": {
                "patient_snapshot": 10,
                "active_conditions": 8,
                "allergies": 5,
                "family_history": 5,
                "medications": 8,
                "medication_adherence": 8,
                "wearable_daily_summaries": 10,
                "device_measurement_summaries": 8,
                "journal_entries": 8,
                "observations": 12,
                "recent_lab_results": 10,
                "recent_imaging_reports": 5,
                "recent_documents": 6,
                "prior_daily_summaries": 8,
                "clinical_episodes": 6,
                "open_alerts": 5,
                "follow_up_reasons": 8,
                "missing_data": 5,
            },
        }.get(normalized, {})

        def _take(items, key):
            if items is None:
                return None
            limit = limits.get(key)
            if limit is None:
                return items
            return items[:limit]

        return SummaryGenerationInput(
            summary_type=payload.summary_type,
            summary_label=payload.summary_label,
            period_start=payload.period_start,
            period_end=payload.period_end,
            data_considered=payload.data_considered,
            patient_snapshot=_take(payload.patient_snapshot, "patient_snapshot"),
            active_conditions=_take(payload.active_conditions, "active_conditions"),
            allergies=_take(payload.allergies, "allergies"),
            family_history=_take(payload.family_history, "family_history"),
            medications=_take(payload.medications, "medications"),
            medication_adherence=_take(payload.medication_adherence, "medication_adherence"),
            wearable_daily_summaries=_take(
                payload.wearable_daily_summaries,
                "wearable_daily_summaries",
            ),
            device_measurement_summaries=_take(
                payload.device_measurement_summaries,
                "device_measurement_summaries",
            ),
            journal_entries=_take(payload.journal_entries, "journal_entries"),
            observations=_take(payload.observations, "observations"),
            recent_lab_results=_take(payload.recent_lab_results, "recent_lab_results"),
            recent_imaging_reports=_take(
                payload.recent_imaging_reports,
                "recent_imaging_reports",
            ),
            recent_documents=_take(payload.recent_documents, "recent_documents"),
            prior_daily_summaries=_take(
                payload.prior_daily_summaries,
                "prior_daily_summaries",
            ),
            open_alerts=_take(payload.open_alerts, "open_alerts"),
            follow_up_reasons=_take(payload.follow_up_reasons, "follow_up_reasons"),
            missing_data=_take(payload.missing_data, "missing_data"),
            clinical_episodes=_take(payload.clinical_episodes, "clinical_episodes"),
        )

    def _minimize_private_local_daily_payload(
        self,
        payload: SummaryGenerationInput,
    ) -> SummaryGenerationInput:
        def _take(items, limit: int | None):
            if items is None or limit is None:
                return items
            return items[:limit]

        return SummaryGenerationInput(
            summary_type=payload.summary_type,
            summary_label=payload.summary_label,
            period_start=payload.period_start,
            period_end=payload.period_end,
            data_considered=_take(payload.data_considered, 6) or [],
            patient_snapshot=_take(payload.patient_snapshot, 4) or [],
            active_conditions=_take(payload.active_conditions, 3) or [],
            allergies=_take(payload.allergies, 2) or [],
            family_history=[],
            medications=_take(payload.medications, 4) or [],
            medication_adherence=_take(payload.medication_adherence, 3) or [],
            wearable_daily_summaries=_take(payload.wearable_daily_summaries, 2) or [],
            device_measurement_summaries=_take(payload.device_measurement_summaries, 2),
            journal_entries=_take(payload.journal_entries, 2) or [],
            observations=_take(payload.observations, 5) or [],
            recent_lab_results=_take(payload.recent_lab_results, 3) or [],
            recent_imaging_reports=_take(payload.recent_imaging_reports, 1) or [],
            recent_documents=_take(payload.recent_documents, 2) or [],
            prior_daily_summaries=_take(payload.prior_daily_summaries, 2) or [],
            open_alerts=_take(payload.open_alerts, 2) or [],
            follow_up_reasons=_take(payload.follow_up_reasons, 3) or [],
            missing_data=_take(payload.missing_data, 3) or [],
            clinical_episodes=_take(payload.clinical_episodes, 2),
        )

    @staticmethod
    def _supports_gemma4_label(model_name: str | None) -> bool:
        normalized = (model_name or "").strip().lower().replace(" ", "").replace("_", "-")
        return "gemma-4" in normalized or normalized.startswith("gemma4")
