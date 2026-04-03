from __future__ import annotations

from sqlalchemy import Boolean, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import BillingInterval


class BillingPlan(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "billing_plans"

    code: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    billing_interval: Mapped[BillingInterval] = mapped_column(
        db_enum(BillingInterval, "billing_interval"),
        default=BillingInterval.FREE,
        nullable=False,
    )
    price_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="EUR", nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    highlight_label: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_recommended: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    feature_links = relationship(
        "BillingPlanFeature",
        back_populates="plan",
        cascade="all, delete-orphan",
    )
    subscriptions = relationship(
        "UserSubscription",
        back_populates="plan",
        cascade="all, delete-orphan",
    )
