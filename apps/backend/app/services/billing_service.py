from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import utcnow
from app.models.billing_feature import BillingFeature
from app.models.billing_plan import BillingPlan
from app.models.enums import BillingInterval, SubscriptionProvider, SubscriptionStatus
from app.models.user import User
from app.models.user_subscription import UserSubscription
from app.repositories.billing_repository import BillingRepository


class BillingFeatureCode:
    CLOUD_DOCUMENT_STORAGE = "cloud_document_storage"
    AI_DAILY_SUMMARY = "ai_daily_summary"
    AI_PERIODIC_SUMMARIES = "ai_periodic_summaries"
    AI_PREVISIT_SUMMARY = "ai_previsit_summary"
    AI_DOCUMENT_QUERY = "ai_document_query"
    AI_REPORT_GENERATION = "ai_report_generation"


@dataclass(slots=True)
class BillingStatusSnapshot:
    current_plan: BillingPlan
    available_plans: list[BillingPlan]
    active_subscription: UserSubscription | None
    entitlement_codes: set[str]


class BillingService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = BillingRepository(db)
        self.settings = get_settings()

    def ensure_catalog_seeded(self) -> None:
        feature_definitions = {
            BillingFeatureCode.CLOUD_DOCUMENT_STORAGE: BillingFeature(
                code=BillingFeatureCode.CLOUD_DOCUMENT_STORAGE,
                name="Archivio documenti cloud",
                description="Salva i documenti nel cloud ClinDiary con cartelle, sync e backup multi-dispositivo.",
                is_ai_feature=False,
            ),
            BillingFeatureCode.AI_DAILY_SUMMARY: BillingFeature(
                code=BillingFeatureCode.AI_DAILY_SUMMARY,
                name="Recap giornaliero AI",
                description="Sblocca il riepilogo giornaliero prudente generato dal modello.",
                is_ai_feature=True,
            ),
            BillingFeatureCode.AI_PERIODIC_SUMMARIES: BillingFeature(
                code=BillingFeatureCode.AI_PERIODIC_SUMMARIES,
                name="Recap settimanali e mensili AI",
                description="Sblocca i recap settimanali e mensili prudenziali.",
                is_ai_feature=True,
            ),
            BillingFeatureCode.AI_PREVISIT_SUMMARY: BillingFeature(
                code=BillingFeatureCode.AI_PREVISIT_SUMMARY,
                name="Recap pre-visita AI",
                description="Prepara una sintesi prudente da portare dal medico.",
                is_ai_feature=True,
            ),
            BillingFeatureCode.AI_DOCUMENT_QUERY: BillingFeature(
                code=BillingFeatureCode.AI_DOCUMENT_QUERY,
                name="Domande ai documenti",
                description="Interroga i documenti clinici con citazioni obbligatorie.",
                is_ai_feature=True,
            ),
            BillingFeatureCode.AI_REPORT_GENERATION: BillingFeature(
                code=BillingFeatureCode.AI_REPORT_GENERATION,
                name="Report AI",
                description="Genera report PDF AI su settimana, mese e pre-visita.",
                is_ai_feature=True,
            ),
        }

        features: dict[str, BillingFeature] = {}
        for code, feature in feature_definitions.items():
            existing = self.repository.get_feature(code)
            if existing is None:
                self.repository.add_feature(feature)
                features[code] = feature
                continue
            existing.name = feature.name
            existing.description = feature.description
            existing.is_ai_feature = feature.is_ai_feature
            features[code] = existing

        free_plan = self._upsert_plan(
            code="free",
            name="ClinDiary Free",
            description="Diario clinico, archivio documenti locale sul dispositivo, prevenzione e promemoria locali.",
            billing_interval=BillingInterval.FREE,
            price_cents=0,
            currency="EUR",
            sort_order=0,
            highlight_label=None,
            is_recommended=False,
        )
        ai_plus_monthly = self._upsert_plan(
            code="ai_plus_monthly",
            name="ClinDiary AI Plus",
            description="Sblocca archivio documenti cloud, OCR, query documentali e tutte le funzioni AI prudenziali.",
            billing_interval=BillingInterval.MONTHLY,
            price_cents=999,
            currency="EUR",
            sort_order=10,
            highlight_label="Piu flessibile",
            is_recommended=False,
        )
        ai_plus_yearly = self._upsert_plan(
            code="ai_plus_yearly",
            name="ClinDiary AI Plus Annuale",
            description="Stesso pacchetto AI Plus con archivio cloud e costo annuale ridotto.",
            billing_interval=BillingInterval.YEARLY,
            price_cents=8999,
            currency="EUR",
            sort_order=20,
            highlight_label="Consigliato",
            is_recommended=True,
        )

        premium_features = list(features.values())
        self.repository.replace_plan_features(free_plan, [])
        self.repository.replace_plan_features(ai_plus_monthly, premium_features)
        self.repository.replace_plan_features(ai_plus_yearly, premium_features)
        self.db.commit()

    def get_status(self, user: User) -> BillingStatusSnapshot:
        self.ensure_catalog_seeded()
        available_plans = self.repository.list_public_plans()
        active_subscription = self.repository.get_active_subscription_for_user(user.id, at_time=utcnow())
        current_plan = (
            active_subscription.plan
            if active_subscription is not None and active_subscription.plan is not None
            else self._require_plan("free")
        )
        entitlement_codes = (
            self.repository.list_feature_codes_for_user(user.id, at_time=utcnow())
            if active_subscription is not None
            else set()
        )
        return BillingStatusSnapshot(
            current_plan=current_plan,
            available_plans=available_plans,
            active_subscription=active_subscription,
            entitlement_codes=entitlement_codes,
        )

    def has_feature(self, user: User, feature_code: str) -> bool:
        status = self.get_status(user)
        return feature_code in status.entitlement_codes

    def has_feature_for_patient(self, patient_id, feature_code: str) -> bool:
        self.ensure_catalog_seeded()
        return feature_code in self.repository.list_feature_codes_for_patient(patient_id, at_time=utcnow())

    def require_feature(
        self,
        user: User,
        feature_code: str,
        *,
        recommended_plan_code: str = "ai_plus_yearly",
        message: str | None = None,
    ) -> None:
        if self.has_feature(user, feature_code):
            return
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "code": "feature_locked",
                "message": message or "Questa funzione AI richiede un piano AI Plus attivo.",
                "feature_code": feature_code,
                "recommended_plan_code": recommended_plan_code,
            },
        )

    def activate_manual_subscription(self, user: User, plan_code: str) -> BillingStatusSnapshot:
        self.ensure_catalog_seeded()
        if not self.settings.debug and self.settings.environment not in {"development", "test"}:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Debug billing disabled")

        plan = self._require_plan(plan_code)
        if plan.code == "free":
            self.cancel_manual_subscription(user)
            return self.get_status(user)

        now = utcnow()
        self.repository.deactivate_subscriptions_for_user(user.id, at_time=now)
        duration = timedelta(days=30 if plan.billing_interval == BillingInterval.MONTHLY else 365)
        subscription = UserSubscription(
            user_id=user.id,
            plan_id=plan.id,
            provider=SubscriptionProvider.MANUAL,
            status=SubscriptionStatus.ACTIVE,
            auto_renew=False,
            started_at=now,
            current_period_start=now,
            current_period_end=now + duration,
        )
        self.repository.add_subscription(subscription)
        self.db.commit()
        return self.get_status(user)

    def cancel_manual_subscription(self, user: User) -> BillingStatusSnapshot:
        if not self.settings.debug and self.settings.environment not in {"development", "test"}:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Debug billing disabled")
        self.ensure_catalog_seeded()
        self.repository.deactivate_subscriptions_for_user(user.id, at_time=utcnow())
        self.db.commit()
        return self.get_status(user)

    def report_feature_code(self, report_type) -> str | None:
        value = getattr(report_type, "value", str(report_type))
        if value == "screening_status_report":
            return None
        return BillingFeatureCode.AI_REPORT_GENERATION

    def summary_feature_code(self, summary_type) -> str:
        value = getattr(summary_type, "value", str(summary_type))
        if value == "daily":
            return BillingFeatureCode.AI_DAILY_SUMMARY
        if value in {"weekly", "monthly"}:
            return BillingFeatureCode.AI_PERIODIC_SUMMARIES
        return BillingFeatureCode.AI_PREVISIT_SUMMARY

    def _require_plan(self, plan_code: str) -> BillingPlan:
        plan = self.repository.get_plan_by_code(plan_code)
        if plan is None or not plan.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Billing plan not found")
        return plan

    def _upsert_plan(
        self,
        *,
        code: str,
        name: str,
        description: str,
        billing_interval: BillingInterval,
        price_cents: int,
        currency: str,
        sort_order: int,
        highlight_label: str | None,
        is_recommended: bool,
    ) -> BillingPlan:
        plan = self.repository.get_plan_by_code(code)
        if plan is None:
            plan = BillingPlan(
                code=code,
                name=name,
                description=description,
                billing_interval=billing_interval,
                price_cents=price_cents,
                currency=currency,
                sort_order=sort_order,
                highlight_label=highlight_label,
                is_recommended=is_recommended,
            )
            self.repository.add_plan(plan)
            return plan

        plan.name = name
        plan.description = description
        plan.billing_interval = billing_interval
        plan.price_cents = price_cents
        plan.currency = currency
        plan.sort_order = sort_order
        plan.highlight_label = highlight_label
        plan.is_recommended = is_recommended
        plan.is_active = True
        plan.is_public = True
        return plan
