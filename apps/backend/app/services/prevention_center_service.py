from __future__ import annotations

from datetime import date, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.enums import (
    AlertStatus,
    BiologicalSex,
    DocumentContextStatus,
    DocumentParsedStatus,
    NotificationType,
)
from app.models.patient_profile import PatientProfile
from app.models.user import User
from app.repositories.alert_repository import AlertRepository
from app.repositories.document_repository import DocumentRepository
from app.repositories.notification_repository import NotificationRepository
from app.services.profile_context import resolve_user_profile
from app.schemas.prevention_center import (
    PreventionCenterOverviewResponse,
    PreventionCenterResponse,
    PreventionRecommendationResponse,
)
from app.services.notification_service import NotificationService
from app.services.screening_service import ITALIAN_SCREENING_REGIONS, ScreeningService


class PreventionCenterService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.screening_service = ScreeningService(db)
        self.notification_service = NotificationService(db)
        self.notification_repository = NotificationRepository(db)
        self.document_repository = DocumentRepository(db)
        self.alert_repository = AlertRepository(db)

    def get_center(
        self,
        user: User,
        *,
        region_code: str | None = None,
    ) -> PreventionCenterResponse:
        profile = self._require_profile(user)
        resolved_region_code = self._region_code_string(region_code or profile.region_code) or "IT"
        self.notification_service.sync_patient_notifications(profile.id)
        screening_items = self.screening_service.list_patient_screenings(
            user,
            region_code=resolved_region_code,
            emit_notifications=False,
        )
        notifications = self.notification_repository.list_active_for_patient(profile.id)
        documents = self.document_repository.list_for_patient(
            profile.id,
            context_status=DocumentContextStatus.ACTIVE,
        )
        alerts = self.alert_repository.list_for_patient(profile.id, status=AlertStatus.OPEN)

        annual_visit = next(
            (item for item in screening_items if item.care_pathway == "annual_visit"),
            None,
        )
        shared_decision_items = self._build_shared_decisions(screening_items)
        visits_and_controls = self._sorted_recommendations(
            [
                self._screening_to_recommendation(item)
                for item in screening_items
                if item.care_pathway not in {"annual_visit", "shared_decision"}
            ]
        )
        vaccines = self._build_vaccine_recommendations(profile)
        vaccine_registry = self._build_vaccine_registry(profile)
        pregnancy_and_preconception = self._build_pregnancy_and_preconception(profile)
        seasonal_checks = self._build_seasonal_checks(profile)
        follow_up_reminders = self._build_follow_up_reminders(
            notifications=notifications,
            alerts=alerts,
            documents=documents,
        )

        actionable_screenings = sum(
            1 for item in screening_items if item.status.value in {"recommended", "overdue"}
        )

        return PreventionCenterResponse(
            generated_at=utcnow(),
            display_name=self._display_name(profile),
            age=self._age(profile.birth_date),
            biological_sex=profile.biological_sex,
            region_code=resolved_region_code,
            region_name=self._region_name_for_code(resolved_region_code),
            overview=PreventionCenterOverviewResponse(
                actionable_screenings=actionable_screenings,
                vaccine_reviews=len(vaccines),
                vaccine_registry_items=len(vaccine_registry),
                pregnancy_items=len(pregnancy_and_preconception),
                shared_decision_items=len(shared_decision_items),
                seasonal_checks=len(seasonal_checks),
                follow_up_items=len(follow_up_reminders),
            ),
            annual_visit=self._screening_to_recommendation(annual_visit) if annual_visit is not None else None,
            visits_and_controls=visits_and_controls,
            vaccines=vaccines,
            vaccine_registry=vaccine_registry,
            pregnancy_and_preconception=pregnancy_and_preconception,
            shared_decisions=shared_decision_items,
            seasonal_checks=seasonal_checks,
            follow_up_reminders=follow_up_reminders,
        )

    def _build_vaccine_recommendations(
        self,
        profile: PatientProfile,
    ) -> list[PreventionRecommendationResponse]:
        age = self._age(profile.birth_date)
        if age is None:
            return [
                PreventionRecommendationResponse(
                    code="vaccination_review_profile_needed",
                    title="Verifica stato vaccinale",
                    subtitle="Completa data di nascita e profilo per suggerimenti piu precisi.",
                    reason="Senza eta e profilo completo ClinDiary puo solo suggerire una revisione generale dei vaccini.",
                    action_hint="Aggiorna il profilo clinico e rivedi il calendario vaccinale con medico o farmacia.",
                    cadence_label="Da verificare",
                    status="review",
                    priority="normal",
                    category="vaccini",
                    kind="vaccine",
                )
            ]

        risk_keywords = self._profile_risk_keywords(profile)
        records = list(profile.vaccination_records)
        items: list[PreventionRecommendationResponse] = [
        ]

        if not self._has_flu_vaccine_for_current_season(records):
            items.append(
                PreventionRecommendationResponse(
                    code="influenza_annual_review",
                    title="Vaccino antinfluenzale",
                    subtitle="Controllo annuale prima o durante la stagione respiratoria.",
                    reason="Il vaccino antinfluenzale va rivisto ogni anno negli adulti.",
                    action_hint="Verifica in autunno con medico, farmacia o servizio vaccinale locale.",
                    cadence_label="Annuale",
                    status="recommended",
                    priority="normal",
                    category="vaccini",
                    kind="vaccine",
                )
            )

        if not self._has_recent_vaccine(
            records,
            keywords=("covid", "comirnaty", "spikevax", "pfizer", "moderna"),
            within_days=365,
        ):
            items.append(
                PreventionRecommendationResponse(
                    code="covid_updated_review",
                    title="Vaccino COVID aggiornato",
                    subtitle="Rivedi i richiami disponibili secondo la stagione e il profilo personale.",
                    reason="L'aggiornamento COVID va rivalutato periodicamente in base alle indicazioni correnti e ai fattori di rischio.",
                    action_hint="Controlla disponibilita e timing del richiamo con medico o farmacia.",
                    cadence_label="Stagionale / periodico",
                    status="review",
                    priority="normal",
                    category="vaccini",
                    kind="vaccine",
                )
            )

        if not self._has_recent_vaccine(
            records,
            keywords=("tetano", "difter", "pertoss", "tdap", "dtap", "td"),
            within_days=3650,
        ):
            items.append(
                PreventionRecommendationResponse(
                    code="tdap_td_booster_review",
                    title="Richiamo tetano-difterite-pertosse",
                    subtitle="Il richiamo si rivaluta ogni 10 anni.",
                    reason="Se l'ultima dose risale a oltre 10 anni fa, conviene verificare il richiamo.",
                    action_hint="Controlla l'ultima dose registrata e pianifica il richiamo se sei oltre 10 anni.",
                    cadence_label="Ogni 10 anni",
                    status="review",
                    priority="low",
                    category="vaccini",
                    kind="vaccine",
                )
            )

        hpv_records = self._matching_vaccines(records, ("hpv", "papilloma"))
        if age <= 26:
            if not hpv_records:
                items.append(
                    PreventionRecommendationResponse(
                        code="hpv_young_adult_review",
                        title="Vaccino HPV",
                        subtitle="Da verificare se il ciclo non e completo.",
                        reason="Negli adulti giovani conviene verificare se la vaccinazione HPV e stata completata.",
                        action_hint="Porta con te il libretto vaccinale e verifica il ciclo con il medico.",
                        cadence_label="Da verificare",
                        status="recommended",
                        priority="normal",
                        category="vaccini",
                        kind="vaccine",
                    )
                )
            elif not self._hpv_series_appears_complete(hpv_records):
                items.append(
                    PreventionRecommendationResponse(
                        code="hpv_series_check",
                        title="Ciclo HPV da confermare",
                        subtitle="Nell'archivio c'e almeno una dose, ma il ciclo potrebbe non essere completo.",
                        reason="Con uno storico parziale conviene verificare se servono altre dosi o se il ciclo e gia concluso.",
                        action_hint="Controlla con il medico o il libretto vaccinale quante dosi hai gia fatto.",
                        cadence_label="Da verificare",
                        status="review",
                        priority="low",
                        category="vaccini",
                        kind="vaccine",
                    )
                )
        elif 27 <= age <= 45:
            if not self._hpv_series_appears_complete(hpv_records):
                items.append(
                    PreventionRecommendationResponse(
                        code="hpv_shared_decision_review",
                        title="Vaccino HPV da discutere",
                        subtitle="Per alcuni adulti puo essere utile una valutazione condivisa.",
                        reason="In questa fascia di eta il vaccino HPV si valuta caso per caso.",
                        action_hint="Se non hai completato il ciclo, discutine in visita.",
                        cadence_label="Valutazione condivisa",
                        status="review",
                        priority="low",
                        category="vaccini",
                        kind="vaccine",
                    )
                )

        if 19 <= age <= 59 and not self._has_any_vaccine(
            records,
            ("epatite b", "hepatitis b", "hbv"),
        ):
            items.append(
                PreventionRecommendationResponse(
                    code="hepatitis_b_review",
                    title="Vaccino epatite B",
                    subtitle="Verifica copertura vaccinale in eta adulta.",
                    reason="Se lo stato vaccinale non e chiaro, vale la pena verificare la protezione per epatite B.",
                    action_hint="Controlla eventuali dosi gia fatte e confrontati con il medico se mancano.",
                    cadence_label="Da verificare",
                    status="review",
                    priority="low",
                    category="vaccini",
                    kind="vaccine",
                )
            )

        if age >= 50 and not self._has_any_vaccine(records, ("zoster", "shingrix", "herpes zoster")):
            items.append(
                PreventionRecommendationResponse(
                    code="zoster_review",
                    title="Vaccino herpes zoster",
                    subtitle="Da considerare in eta adulta matura.",
                    reason="Dopo i 50 anni conviene rivedere il vaccino contro l'herpes zoster.",
                    action_hint="Verifica disponibilita e timing con il medico o il servizio vaccinale.",
                    cadence_label="Secondo ciclo previsto",
                    status="recommended",
                    priority="normal",
                    category="vaccini",
                    kind="vaccine",
                )
            )

        if (
            age >= 50 or risk_keywords.intersection({"diabete", "asma", "bpco", "cuore", "rene", "immunitario"})
        ) and not self._has_any_vaccine(
            records,
            ("pneumoc", "prevnar", "pneumovax"),
        ):
            items.append(
                PreventionRecommendationResponse(
                    code="pneumococcal_review",
                    title="Vaccino pneumococcico",
                    subtitle="Utile da rivedere con eta o condizioni predisponenti.",
                    reason="Eta e alcune condizioni croniche rendono opportuna una revisione del vaccino pneumococcico.",
                    action_hint="Porta in visita i tuoi problemi cronici attivi e verifica se il vaccino e indicato.",
                    cadence_label="Da verificare",
                    status="review",
                    priority="normal",
                    category="vaccini",
                    kind="vaccine",
                )
            )

        if age >= 75 or (
            age >= 60 and risk_keywords.intersection({"asma", "bpco", "cuore", "rene", "immunitario", "diabete"})
        ) and not self._has_any_vaccine(records, ("rsv", "abrysvo", "arexvy", "mresvia")):
            items.append(
                PreventionRecommendationResponse(
                    code="rsv_review",
                    title="Vaccino RSV",
                    subtitle="Da discutere se l'eta o il profilo clinico lo rendono rilevante.",
                    reason="Per alcuni adulti piu grandi o con fattori di rischio puo essere utile una revisione del vaccino RSV.",
                    action_hint="Verifica indicazione e timing con il medico nella prossima visita.",
                    cadence_label="Valutazione per eta/rischio",
                    status="review",
                    priority="low",
                    category="vaccini",
                    kind="vaccine",
                )
            )

        return self._sorted_recommendations(items)

    def _build_vaccine_registry(
        self,
        profile: PatientProfile,
    ) -> list[PreventionRecommendationResponse]:
        age = self._age(profile.birth_date)
        records = list(profile.vaccination_records)
        if age is None:
            return []

        registry: list[PreventionRecommendationResponse] = []

        registry.append(
            self._registry_item(
                code="registry_influenza",
                title="Influenza",
                subtitle="Stagione corrente",
                status="up_to_date"
                if self._has_flu_vaccine_for_current_season(records)
                else "recommended",
                reason="Vaccino registrato per la stagione corrente."
                if self._has_flu_vaccine_for_current_season(records)
                else "Non risulta una dose registrata per la stagione influenzale corrente.",
                action_hint="Tieni aggiornato lo storico vaccinale e verifica ogni autunno.",
                cadence_label="Annuale",
            )
        )
        registry.append(
            self._registry_item(
                code="registry_covid",
                title="COVID",
                subtitle="Richiami periodici",
                status="up_to_date"
                if self._has_recent_vaccine(
                    records,
                    keywords=("covid", "comirnaty", "spikevax", "pfizer", "moderna"),
                    within_days=365,
                )
                else "review",
                reason="Nello storico e presente un richiamo recente."
                if self._has_recent_vaccine(
                    records,
                    keywords=("covid", "comirnaty", "spikevax", "pfizer", "moderna"),
                    within_days=365,
                )
                else "Non emerge un richiamo COVID recente nello storico registrato.",
                action_hint="Aggiorna la scheda quando fai un richiamo.",
                cadence_label="Periodico",
            )
        )
        registry.append(
            self._registry_item(
                code="registry_tdap_td",
                title="Td/Tdap",
                subtitle="Richiamo tetano-difterite-pertosse",
                status="up_to_date"
                if self._has_recent_vaccine(
                    records,
                    keywords=("tetano", "difter", "pertoss", "tdap", "dtap", "td"),
                    within_days=3650,
                )
                else "review",
                reason="Richiamo registrato negli ultimi 10 anni."
                if self._has_recent_vaccine(
                    records,
                    keywords=("tetano", "difter", "pertoss", "tdap", "dtap", "td"),
                    within_days=3650,
                )
                else "Non emerge un richiamo recente nello storico registrato.",
                action_hint="Se aggiorni un richiamo qui, il Centro prevenzione lo usera automaticamente.",
                cadence_label="Ogni 10 anni",
            )
        )
        hpv_records = self._matching_vaccines(records, ("hpv", "papilloma"))
        if age <= 45:
            registry.append(
                self._registry_item(
                    code="registry_hpv",
                    title="HPV",
                    subtitle="Ciclo vaccinale",
                    status="up_to_date"
                    if self._hpv_series_appears_complete(hpv_records)
                    else "review",
                    reason="Il ciclo HPV sembra completo nello storico."
                    if self._hpv_series_appears_complete(hpv_records)
                    else "Lo storico HPV sembra incompleto o non documentato.",
                    action_hint="Aggiungi le dosi mancanti o verifica il ciclo con il medico.",
                    cadence_label="Da verificare",
                )
            )
        if age >= 50:
            registry.append(
                self._registry_item(
                    code="registry_zoster",
                    title="Herpes zoster",
                    subtitle="Protezione in eta adulta",
                    status="up_to_date"
                    if self._has_any_vaccine(records, ("zoster", "shingrix", "herpes zoster"))
                    else "recommended",
                    reason="Vaccino zoster gia registrato."
                    if self._has_any_vaccine(records, ("zoster", "shingrix", "herpes zoster"))
                    else "Non risulta un vaccino zoster nello storico.",
                    action_hint="Registra il vaccino quando lo fai, cosi i reminder saranno piu precisi.",
                    cadence_label="Secondo ciclo previsto",
                )
            )

        risk_keywords = self._profile_risk_keywords(profile)
        if age >= 50 or risk_keywords.intersection({"diabete", "asma", "bpco", "cuore", "rene", "immunitario"}):
            registry.append(
                self._registry_item(
                    code="registry_pneumococcal",
                    title="Pneumococco",
                    subtitle="Eta o condizioni predisponenti",
                    status="up_to_date"
                    if self._has_any_vaccine(records, ("pneumoc", "prevnar", "pneumovax"))
                    else "review",
                    reason="Vaccino pneumococcico gia registrato."
                    if self._has_any_vaccine(records, ("pneumoc", "prevnar", "pneumovax"))
                    else "Non emerge un vaccino pneumococcico nello storico registrato.",
                    action_hint="Verifica con il medico se il tuo profilo lo rende indicato.",
                    cadence_label="Da verificare",
                )
            )

        return self._sorted_recommendations(registry)

    def _build_pregnancy_and_preconception(
        self,
        profile: PatientProfile,
    ) -> list[PreventionRecommendationResponse]:
        age = self._age(profile.birth_date)
        if profile.biological_sex != BiologicalSex.FEMALE or age is None:
            return []

        items: list[PreventionRecommendationResponse] = []
        if profile.trying_to_conceive:
            items.append(
                PreventionRecommendationResponse(
                    code="preconception_review",
                    title="Percorso preconcezionale",
                    subtitle="Farmaci, vaccini e condizioni note da rivedere prima del concepimento.",
                    reason="Hai indicato che stai cercando una gravidanza.",
                    action_hint="Porta in visita farmaci attivi, referti recenti e storico vaccinale.",
                    cadence_label="Prima del concepimento",
                    status="recommended",
                    priority="normal",
                    category="gravidanza_preconcepimento",
                    kind="pregnancy",
                )
            )
            if not profile.taking_folic_acid:
                items.append(
                    PreventionRecommendationResponse(
                        code="folic_acid_review",
                        title="Folati da discutere",
                        subtitle="Nel percorso preconcezionale conviene verificare l'integrazione di acido folico.",
                        reason="Nel profilo non risulta indicata integrazione di folati.",
                        action_hint="Chiedi al medico quale integrazione sia appropriata per te.",
                        cadence_label="Prima del concepimento",
                        status="review",
                        priority="normal",
                        category="gravidanza_preconcepimento",
                        kind="pregnancy",
                    )
                )
        if profile.currently_pregnant:
            items.append(
                PreventionRecommendationResponse(
                    code="pregnancy_review",
                    title="Revisione prevenzione in gravidanza",
                    subtitle="Vaccini, farmaci e follow-up vanno riletti nel contesto della gravidanza.",
                    reason="Hai indicato che la gravidanza e in corso.",
                    action_hint="Rivedi con medico o ostetrica lo storico vaccinale e i farmaci attivi.",
                    cadence_label="Durante la gravidanza",
                    status="recommended",
                    priority="normal",
                    category="gravidanza_preconcepimento",
                    kind="pregnancy",
                )
            )
        if not items:
            return []

        if profile.medications:
            items.append(
                PreventionRecommendationResponse(
                    code="pregnancy_medication_review",
                    title="Rilettura dei farmaci attivi",
                    subtitle="Con preconcezione o gravidanza e utile rivedere le terapie attive.",
                    reason="Nel profilo ci sono farmaci attivi che vanno contestualizzati nel percorso riproduttivo.",
                    action_hint="Non sospendere nulla da sola: usa la lista farmaci come base per la visita.",
                    cadence_label="Da discutere",
                    status="attention",
                    priority="high",
                    category="gravidanza_preconcepimento",
                    kind="pregnancy",
                )
            )

        return self._sorted_recommendations(items)

    def _build_shared_decisions(
        self,
        screening_items,
    ) -> list[PreventionRecommendationResponse]:
        return self._sorted_recommendations(
            [
                self._screening_to_recommendation(item)
                for item in screening_items
                if item.care_pathway == "shared_decision"
            ]
        )

    def _build_seasonal_checks(
        self,
        profile: PatientProfile,
    ) -> list[PreventionRecommendationResponse]:
        today = date.today()
        month = today.month
        risk_keywords = self._profile_risk_keywords(profile)
        items: list[PreventionRecommendationResponse] = []

        if month in {9, 10, 11}:
            items.append(
                PreventionRecommendationResponse(
                    code="autumn_respiratory_review",
                    title="Preparazione autunno-inverno",
                    subtitle="Rivedi vaccini respiratori, controlli programmati e scorte dei farmaci cronici.",
                    reason="L'inizio della stagione respiratoria e un buon momento per aggiornare il piano preventivo.",
                    action_hint="Organizza per tempo vaccini, refill e controlli gia dovuti.",
                    cadence_label="Stagionale",
                    status="seasonal",
                    priority="normal",
                    category="stagionale",
                    kind="seasonal_check",
                )
            )

        if month in {12, 1, 2} and risk_keywords.intersection({"asma", "bpco", "cuore", "diabete", "rene"}):
            items.append(
                PreventionRecommendationResponse(
                    code="winter_chronic_follow_up",
                    title="Follow-up condizioni croniche in inverno",
                    subtitle="In presenza di patologie croniche conviene verificare se servono controlli o aggiustamenti organizzativi.",
                    reason="La stagione fredda puo rendere piu pesanti sintomi respiratori e gestione quotidiana delle condizioni croniche.",
                    action_hint="Se i sintomi peggiorano o i parametri cambiano, anticipa il contatto con il medico.",
                    cadence_label="Stagionale",
                    status="seasonal",
                    priority="normal",
                    category="stagionale",
                    kind="seasonal_check",
                )
            )

        if month in {3, 4, 5} and self._has_allergy_context(profile):
            items.append(
                PreventionRecommendationResponse(
                    code="spring_allergy_review",
                    title="Revisione allergie stagionali",
                    subtitle="La primavera e il momento giusto per rivedere trigger, terapia e documenti utili.",
                    reason="Profilo, allergie o trigger fanno pensare a una componente stagionale che merita una revisione pratica.",
                    action_hint="Aggiorna il diario, porta i referti utili e valuta se serve una visita dedicata.",
                    cadence_label="Stagionale",
                    status="seasonal",
                    priority="normal",
                    category="stagionale",
                    kind="seasonal_check",
                )
            )

        if month in {6, 7, 8}:
            items.append(
                PreventionRecommendationResponse(
                    code="summer_heat_hydration_review",
                    title="Caldo, idratazione e routine estiva",
                    subtitle="Controlla se sonno, idratazione o pressione cambiano con il caldo.",
                    reason="Con temperature alte vale la pena monitorare come cambiano energia, sonno e benessere generale.",
                    action_hint="Usa il diario per tracciare eventuali cambiamenti e anticipa la visita se il caldo pesa molto.",
                    cadence_label="Stagionale",
                    status="seasonal",
                    priority="low",
                    category="stagionale",
                    kind="seasonal_check",
                )
            )

        return items

    def _build_follow_up_reminders(
        self,
        *,
        notifications,
        alerts,
        documents,
    ) -> list[PreventionRecommendationResponse]:
        items: list[PreventionRecommendationResponse] = []
        seen: set[tuple[str | None, object | None]] = set()

        for notification in notifications:
            if notification.notification_type == NotificationType.DAILY_CHECKIN_REMINDER:
                continue
            key = (notification.source_type, notification.source_id)
            if key in seen:
                continue
            seen.add(key)
            items.append(
                PreventionRecommendationResponse(
                    code=f"notification_{notification.notification_type.value}_{notification.id}",
                    title=notification.title,
                    subtitle=notification.body,
                    reason=notification.body,
                    action_hint=self._action_hint_for_notification_type(notification.notification_type),
                    cadence_label="Da rivedere",
                    status=self._status_for_notification_type(notification.notification_type),
                    priority=notification.priority.value,
                    category="follow_up",
                    kind="follow_up",
                    source_type=notification.source_type,
                    source_id=notification.source_id,
                )
            )

        actionable_document_statuses = {
            DocumentParsedStatus.PENDING,
            DocumentParsedStatus.OCR_PENDING,
            DocumentParsedStatus.REVIEW_REQUIRED,
            DocumentParsedStatus.FAILED,
        }
        for document in documents:
            key = ("clinical_document", document.id)
            if key in seen:
                continue
            if document.parsed_status not in actionable_document_statuses:
                continue
            seen.add(key)
            items.append(
                PreventionRecommendationResponse(
                    code=f"document_follow_up_{document.id}",
                    title=f"Documento da completare: {document.title}",
                    subtitle=document.processing_error or "Documento ancora da controllare o completare.",
                    reason=document.processing_error or "Il dossier contiene un documento non ancora consolidato.",
                    action_hint="Apri la sezione Documenti e completa review o processing.",
                    cadence_label="Follow-up",
                    status="review",
                    priority="normal",
                    category="follow_up",
                    kind="follow_up",
                    source_type="clinical_document",
                    source_id=document.id,
                )
            )

        for alert in alerts:
            key = ("alert", alert.id)
            if key in seen:
                continue
            seen.add(key)
            items.append(
                PreventionRecommendationResponse(
                    code=f"alert_follow_up_{alert.id}",
                    title=alert.title,
                    subtitle=alert.description,
                    reason=alert.description,
                    action_hint="Se il problema persiste o peggiora, contatta il medico secondo il livello di priorita indicato.",
                    cadence_label="Follow-up",
                    status="attention",
                    priority="urgent" if alert.severity.value == "urgency" else "high",
                    category="follow_up",
                    kind="follow_up",
                    source_type="alert",
                    source_id=alert.id,
                )
            )

        return items[:8]

    @staticmethod
    def _screening_to_recommendation(item) -> PreventionRecommendationResponse:
        return PreventionRecommendationResponse(
            code=item.screening_code,
            title=item.screening_name,
            subtitle=item.recommendation_reason,
            reason=item.explanation or item.recommendation_reason,
            action_hint="Segnalo come completato oppure portalo nella prossima visita.",
            cadence_label=item.cadence_label,
            status=item.status.value,
            priority="high" if item.status.value == "overdue" else "normal",
            category=item.screening_category,
            kind="screening",
            source_type="patient_screening_status",
            source_id=item.id,
        )

    @staticmethod
    def _action_hint_for_notification_type(notification_type: NotificationType) -> str:
        return {
            NotificationType.SCREENING_REMINDER: "Apri la sezione prevenzione e programma il controllo.",
            NotificationType.DOCUMENT_FOLLOW_UP: "Controlla il documento, completa il processing o fai review.",
            NotificationType.REPORT_READY: "Apri il PDF dal dossier o dalla sezione report.",
            NotificationType.CLINICAL_ALERT: "Rivedi l'alert e valuta un contatto medico se indicato.",
            NotificationType.PREVENTION_TIP: "Usa il promemoria come spunto per organizzare la prevenzione.",
        }.get(notification_type, "Rivedi il promemoria e aggiorna il tuo piano di follow-up.")

    @staticmethod
    def _status_for_notification_type(notification_type: NotificationType) -> str:
        return {
            NotificationType.SCREENING_REMINDER: "recommended",
            NotificationType.DOCUMENT_FOLLOW_UP: "review",
            NotificationType.REPORT_READY: "ready",
            NotificationType.CLINICAL_ALERT: "attention",
            NotificationType.PREVENTION_TIP: "review",
        }.get(notification_type, "review")

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
    def _has_allergy_context(profile: PatientProfile) -> bool:
        allergy_text = " ".join(
            [
                *(item.allergen.lower() for item in profile.allergies),
                *(item.notes.lower() for item in profile.allergies if item.notes),
                (profile.symptom_triggers or "").lower(),
            ]
        )
        return any(keyword in allergy_text for keyword in ("allerg", "poll", "gramin", "acari"))

    @staticmethod
    def _profile_risk_keywords(profile: PatientProfile) -> set[str]:
        fields = [
            *(item.name.lower() for item in profile.conditions),
            *(item.notes.lower() for item in profile.conditions if item.notes),
            *(item.condition_name.lower() for item in profile.family_history_entries),
            (profile.occupation or "").lower(),
            (profile.exercise_habits or "").lower(),
            (profile.sleep_pattern or "").lower(),
        ]
        haystack = " ".join(fields)
        keywords = {
            "asma": ("asma",),
            "bpco": ("bpco", "copd", "bronco"),
            "cuore": ("cardio", "cuore", "infarto", "scompenso"),
            "rene": ("rene", "renale", "kidney"),
            "diabete": ("diabet", "glicem"),
            "immunitario": ("immun", "trapiant", "oncolog", "chemi"),
            "pressione": ("ipert", "pressione"),
            "colesterolo": ("colester", "dislip"),
        }
        result = {label for label, variants in keywords.items() if any(token in haystack for token in variants)}
        if profile.smoker:
            result.add("fumo")
        if profile.alcohol_use and profile.alcohol_use.value == "high":
            result.add("alcol")
        return result

    @staticmethod
    def _sorted_recommendations(
        items: list[PreventionRecommendationResponse],
    ) -> list[PreventionRecommendationResponse]:
        priority_rank = {"urgent": 0, "high": 1, "normal": 2, "low": 3}
        status_rank = {
            "overdue": 0,
            "recommended": 1,
            "attention": 2,
            "review": 3,
            "seasonal": 4,
            "ready": 5,
            "shared_decision": 6,
            "up_to_date": 7,
        }
        return sorted(
            items,
            key=lambda item: (
                priority_rank.get(item.priority, 9),
                status_rank.get(item.status, 9),
                item.title.lower(),
            ),
        )

    @staticmethod
    def _registry_item(
        *,
        code: str,
        title: str,
        subtitle: str,
        status: str,
        reason: str,
        action_hint: str,
        cadence_label: str,
    ) -> PreventionRecommendationResponse:
        return PreventionRecommendationResponse(
            code=code,
            title=title,
            subtitle=subtitle,
            reason=reason,
            action_hint=action_hint,
            cadence_label=cadence_label,
            status=status,
            priority="low" if status == "up_to_date" else "normal",
            category="vaccini",
            kind="vaccine_registry",
        )

    @staticmethod
    def _matching_vaccines(profile_records, keywords: tuple[str, ...]):
        return [
            record
            for record in profile_records
            if any(keyword in (record.vaccine_name or "").lower() for keyword in keywords)
        ]

    @classmethod
    def _has_any_vaccine(cls, profile_records, keywords: tuple[str, ...]) -> bool:
        return bool(cls._matching_vaccines(profile_records, keywords))

    @classmethod
    def _has_recent_vaccine(
        cls,
        profile_records,
        *,
        keywords: tuple[str, ...],
        within_days: int,
    ) -> bool:
        today = date.today()
        threshold = today - timedelta(days=within_days)
        for record in cls._matching_vaccines(profile_records, keywords):
            if record.administered_on is not None and record.administered_on >= threshold:
                return True
        return False

    @classmethod
    def _has_flu_vaccine_for_current_season(cls, profile_records) -> bool:
        today = date.today()
        season_start_year = today.year if today.month >= 9 else today.year - 1
        season_start = date(season_start_year, 9, 1)
        for record in cls._matching_vaccines(profile_records, ("influenz", "antinflu")):
            if record.administered_on is not None and record.administered_on >= season_start:
                return True
        return False

    @staticmethod
    def _hpv_series_appears_complete(profile_records) -> bool:
        if not profile_records:
            return False
        explicit_max_dose = max((record.dose_number or 0) for record in profile_records)
        if explicit_max_dose >= 3:
            return True
        return len([record for record in profile_records if record.administered_on is not None]) >= 2

    @staticmethod
    def _require_profile(user: User) -> PatientProfile:
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    @staticmethod
    def _region_code_string(region_code) -> str | None:
        if region_code is None:
            return None
        value = getattr(region_code, "value", region_code)
        return str(value).upper()

    @staticmethod
    def _region_name_for_code(region_code: str | None) -> str | None:
        if region_code is None:
            return None
        normalized = region_code.strip().upper()
        for code, name in ITALIAN_SCREENING_REGIONS:
            if code.upper() == normalized:
                return name
        return region_code
