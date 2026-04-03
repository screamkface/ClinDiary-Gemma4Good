from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import SubscriptionProvider, SubscriptionStatus


class UserSubscription(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "user_subscriptions"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[str] = mapped_column(ForeignKey("billing_plans.id", ondelete="CASCADE"), index=True)
    provider: Mapped[SubscriptionProvider] = mapped_column(
        db_enum(SubscriptionProvider, "subscription_provider"),
        default=SubscriptionProvider.MANUAL,
        nullable=False,
    )
    status: Mapped[SubscriptionStatus] = mapped_column(
        db_enum(SubscriptionStatus, "subscription_status"),
        default=SubscriptionStatus.ACTIVE,
        nullable=False,
        index=True,
    )
    provider_reference: Mapped[str | None] = mapped_column(String(255))
    auto_renew: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    current_period_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    canceled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    trial_ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user = relationship("User", back_populates="subscriptions")
    plan = relationship("BillingPlan", back_populates="subscriptions")
