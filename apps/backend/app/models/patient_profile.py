from __future__ import annotations

from datetime import date

from sqlalchemy import Boolean, Date, Float, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin, db_enum
from app.models.enums import ActivityLevel, AlcoholUse, BiologicalSex, ItalianRegionCode


class PatientProfile(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "patient_profiles"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    is_primary: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    first_name: Mapped[str | None]
    last_name: Mapped[str | None]
    birth_date: Mapped[date | None] = mapped_column(Date)
    biological_sex: Mapped[BiologicalSex | None] = mapped_column(
        db_enum(BiologicalSex, "biological_sex")
    )
    height_cm: Mapped[float | None] = mapped_column(Float)
    weight_kg: Mapped[float | None] = mapped_column(Float)
    smoker: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    former_smoker: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    smoking_pack_years: Mapped[float | None] = mapped_column(Float)
    years_since_quitting: Mapped[int | None]
    alcohol_use: Mapped[AlcoholUse | None] = mapped_column(
        db_enum(AlcoholUse, "alcohol_use")
    )
    activity_level: Mapped[ActivityLevel | None] = mapped_column(
        db_enum(ActivityLevel, "activity_level")
    )
    postmenopausal: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    fragility_fracture_history: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    falls_last_year: Mapped[int | None]
    feels_unsteady: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sexually_active: Mapped[bool | None] = mapped_column(Boolean)
    new_or_multiple_partners: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    partner_with_sti: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sex_with_men: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sti_or_exposure_concerns: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    trying_to_conceive: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    currently_pregnant: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    taking_folic_acid: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    region_code: Mapped[ItalianRegionCode | None] = mapped_column(
        db_enum(ItalianRegionCode, "italian_region_code")
    )
    occupation: Mapped[str | None] = mapped_column(Text)
    relationship_label: Mapped[str | None] = mapped_column(Text)
    exercise_habits: Mapped[str | None] = mapped_column(Text)
    sleep_pattern: Mapped[str | None] = mapped_column(Text)
    symptom_triggers: Mapped[str | None] = mapped_column(Text)
    functional_limitations: Mapped[str | None] = mapped_column(Text)

    user = relationship("User", foreign_keys=[user_id])
    allergies = relationship("Allergy", back_populates="patient", cascade="all, delete-orphan")
    conditions = relationship(
        "MedicalCondition",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    medications = relationship(
        "Medication",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    family_history_entries = relationship(
        "FamilyHistoryEntry",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    vaccination_records = relationship(
        "VaccinationRecord",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    clinical_episodes = relationship(
        "ClinicalEpisode",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    daily_entries = relationship(
        "DailyEntry",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    timeline_events = relationship(
        "TimelineEvent",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    clinical_documents = relationship(
        "ClinicalDocument",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    document_chunks = relationship(
        "DocumentChunk",
        cascade="all, delete-orphan",
    )
    document_folders = relationship(
        "DocumentFolder",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    ai_summaries = relationship(
        "AiSummary",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    alerts = relationship(
        "Alert",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    reports = relationship(
        "Report",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    screening_statuses = relationship(
        "PatientScreeningStatus",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    screening_completion_records = relationship(
        "ScreeningCompletionRecord",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    notifications = relationship(
        "Notification",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    notification_preferences = relationship(
        "NotificationPreference",
        back_populates="patient",
        uselist=False,
        cascade="all, delete-orphan",
    )
    notification_device_tokens = relationship(
        "NotificationDeviceToken",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    screening_notifications = relationship(
        "ScreeningNotification",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    wearable_daily_summaries = relationship(
        "WearableDailySummary",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    device_connections = relationship(
        "DeviceConnection",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    device_measurements = relationship(
        "DeviceMeasurement",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    device_import_jobs = relationship(
        "DeviceImportJob",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    dossier_share_links = relationship(
        "DossierShareLink",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
