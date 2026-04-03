from __future__ import annotations

from sqlalchemy import Boolean, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class BillingFeature(Base, TimestampMixin):
    __tablename__ = "billing_features"

    code: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    is_ai_feature: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    plan_links = relationship(
        "BillingPlanFeature",
        back_populates="feature",
        cascade="all, delete-orphan",
    )
