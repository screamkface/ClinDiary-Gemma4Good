from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import BillingInterval, SubscriptionProvider, SubscriptionStatus


class BillingPlanResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    code: str
    name: str
    description: str | None
    billing_interval: BillingInterval
    price_cents: int
    currency: str
    sort_order: int
    highlight_label: str | None
    is_active: bool
    is_public: bool
    is_recommended: bool
    feature_codes: list[str] = Field(default_factory=list)


class UserSubscriptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    provider: SubscriptionProvider
    status: SubscriptionStatus
    auto_renew: bool
    started_at: datetime
    current_period_start: datetime
    current_period_end: datetime | None
    canceled_at: datetime | None
    trial_ends_at: datetime | None
    plan: BillingPlanResponse


class BillingStatusResponse(BaseModel):
    current_plan: BillingPlanResponse
    available_plans: list[BillingPlanResponse]
    active_subscription: UserSubscriptionResponse | None = None
    entitlement_codes: list[str] = Field(default_factory=list)
    has_active_paid_subscription: bool = False
    checkout_ready: bool = False


class BillingActivateRequest(BaseModel):
    plan_code: str


class BillingActivateResponse(BaseModel):
    message: str
    status: BillingStatusResponse
