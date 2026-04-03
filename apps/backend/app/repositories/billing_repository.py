from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, joinedload

from app.core.security import utcnow
from app.models.billing_feature import BillingFeature
from app.models.billing_plan import BillingPlan
from app.models.billing_plan_feature import BillingPlanFeature
from app.models.patient_profile import PatientProfile
from app.models.user_subscription import UserSubscription
from app.models.enums import SubscriptionStatus


class BillingRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def has_any_plan(self) -> bool:
        return self.db.scalar(select(BillingPlan.id).limit(1)) is not None

    def list_public_plans(self) -> list[BillingPlan]:
        stmt = (
            select(BillingPlan)
            .options(joinedload(BillingPlan.feature_links).joinedload(BillingPlanFeature.feature))
            .where(BillingPlan.is_active.is_(True), BillingPlan.is_public.is_(True))
            .order_by(BillingPlan.sort_order.asc(), BillingPlan.name.asc())
        )
        return list(self.db.scalars(stmt).unique().all())

    def get_plan_by_code(self, code: str) -> BillingPlan | None:
        stmt = (
            select(BillingPlan)
            .options(joinedload(BillingPlan.feature_links).joinedload(BillingPlanFeature.feature))
            .where(BillingPlan.code == code)
        )
        return self.db.scalar(stmt)

    def get_feature(self, code: str) -> BillingFeature | None:
        return self.db.get(BillingFeature, code)

    def add_feature(self, feature: BillingFeature) -> BillingFeature:
        self.db.add(feature)
        return feature

    def add_plan(self, plan: BillingPlan) -> BillingPlan:
        self.db.add(plan)
        return plan

    def replace_plan_features(self, plan: BillingPlan, features: list[BillingFeature]) -> None:
        plan.feature_links.clear()
        for feature in features:
            plan.feature_links.append(BillingPlanFeature(feature=feature))

    def get_active_subscription_for_user(
        self,
        user_id: UUID,
        *,
        at_time: datetime | None = None,
    ) -> UserSubscription | None:
        reference = at_time or utcnow()
        stmt = (
            select(UserSubscription)
            .options(joinedload(UserSubscription.plan).joinedload(BillingPlan.feature_links).joinedload(BillingPlanFeature.feature))
            .where(UserSubscription.user_id == user_id)
            .where(UserSubscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]))
            .where(
                or_(
                    UserSubscription.current_period_end.is_(None),
                    UserSubscription.current_period_end >= reference,
                )
            )
            .order_by(UserSubscription.current_period_end.desc().nullslast(), UserSubscription.created_at.desc())
        )
        return self.db.scalar(stmt)

    def list_feature_codes_for_user(
        self,
        user_id: UUID,
        *,
        at_time: datetime | None = None,
    ) -> set[str]:
        subscription = self.get_active_subscription_for_user(user_id, at_time=at_time)
        if subscription is None or subscription.plan is None:
            return set()
        return {
            link.feature_code
            for link in subscription.plan.feature_links
            if link.feature is not None
        }

    def list_feature_codes_for_patient(
        self,
        patient_id: UUID,
        *,
        at_time: datetime | None = None,
    ) -> set[str]:
        stmt = select(PatientProfile.user_id).where(PatientProfile.id == patient_id)
        user_id = self.db.scalar(stmt)
        if user_id is None:
            return set()
        return self.list_feature_codes_for_user(user_id, at_time=at_time)

    def deactivate_subscriptions_for_user(
        self,
        user_id: UUID,
        *,
        at_time: datetime,
    ) -> None:
        stmt = select(UserSubscription).where(
            UserSubscription.user_id == user_id,
            UserSubscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]),
        )
        for subscription in self.db.scalars(stmt):
            subscription.status = SubscriptionStatus.CANCELED
            subscription.canceled_at = at_time
            subscription.current_period_end = at_time

    def add_subscription(self, subscription: UserSubscription) -> UserSubscription:
        self.db.add(subscription)
        return subscription
