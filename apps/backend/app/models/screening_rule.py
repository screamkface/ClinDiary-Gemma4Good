from __future__ import annotations

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import ActivityLevel, AlcoholUse, BiologicalSex


class ScreeningRule(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "screening_rules"

    screening_program_id: Mapped[str] = mapped_column(
        ForeignKey("screening_programs.id", ondelete="CASCADE")
    )
    rule_code: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    min_age: Mapped[int | None] = mapped_column(Integer)
    max_age: Mapped[int | None] = mapped_column(Integer)
    target_sex: Mapped[BiologicalSex | None] = mapped_column(
        db_enum(BiologicalSex, "biological_sex"),
    )
    smoker_required: Mapped[bool | None] = mapped_column(Boolean)
    family_history_keyword: Mapped[str | None] = mapped_column(String(255))
    condition_keyword: Mapped[str | None] = mapped_column(String(255))
    alcohol_use_required: Mapped[AlcoholUse | None] = mapped_column(
        db_enum(AlcoholUse, "alcohol_use"),
    )
    activity_level_required: Mapped[ActivityLevel | None] = mapped_column(
        db_enum(ActivityLevel, "activity_level"),
    )
    min_bmi: Mapped[float | None] = mapped_column(Float)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    screening_program = relationship("ScreeningProgram", back_populates="rules")
