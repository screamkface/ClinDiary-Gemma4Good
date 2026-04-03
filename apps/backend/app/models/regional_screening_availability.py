from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class RegionalScreeningAvailability(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "regional_screening_availability"

    screening_program_id: Mapped[str] = mapped_column(
        ForeignKey("screening_programs.id", ondelete="CASCADE")
    )
    region_code: Mapped[str] = mapped_column(String(50), nullable=False)
    region_name: Mapped[str] = mapped_column(String(255), nullable=False)
    booking_url: Mapped[str | None] = mapped_column(String(512))
    notes: Mapped[str | None] = mapped_column(Text)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    screening_program = relationship(
        "ScreeningProgram",
        back_populates="regional_availability",
    )
