from __future__ import annotations

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class BillingPlanFeature(Base):
    __tablename__ = "billing_plan_features"

    plan_id: Mapped[str] = mapped_column(
        ForeignKey("billing_plans.id", ondelete="CASCADE"),
        primary_key=True,
    )
    feature_code: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("billing_features.code", ondelete="CASCADE"),
        primary_key=True,
    )

    plan = relationship("BillingPlan", back_populates="feature_links")
    feature = relationship("BillingFeature", back_populates="plan_links")
