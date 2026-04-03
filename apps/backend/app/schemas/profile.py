from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import (
    ActivityLevel,
    AlcoholUse,
    AllergySeverity,
    BiologicalSex,
    ConditionStatus,
    ItalianRegionCode,
)
from app.schemas.medications import MedicationScheduleCreateRequest, MedicationScheduleResponse


class OnboardingStatusResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    health_data_consent: bool
    consented_at: datetime | None
    ai_external_consent: bool
    ai_external_consented_at: datetime | None
    onboarding_completed_at: datetime | None


class PatientProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    first_name: str | None
    last_name: str | None
    birth_date: date | None
    biological_sex: BiologicalSex | None
    height_cm: float | None
    weight_kg: float | None
    smoker: bool
    former_smoker: bool
    smoking_pack_years: float | None
    years_since_quitting: int | None
    alcohol_use: AlcoholUse | None
    activity_level: ActivityLevel | None
    postmenopausal: bool
    fragility_fracture_history: bool
    falls_last_year: int | None
    feels_unsteady: bool
    sexually_active: bool | None
    new_or_multiple_partners: bool
    partner_with_sti: bool
    sex_with_men: bool
    sti_or_exposure_concerns: bool
    trying_to_conceive: bool
    currently_pregnant: bool
    taking_folic_acid: bool
    region_code: ItalianRegionCode | None
    occupation: str | None
    relationship_label: str | None
    exercise_habits: str | None
    sleep_pattern: str | None
    symptom_triggers: str | None
    functional_limitations: str | None
    is_primary: bool


class ProfileUpdateRequest(BaseModel):
    first_name: str | None = Field(default=None, max_length=255)
    last_name: str | None = Field(default=None, max_length=255)
    birth_date: date | None = None
    biological_sex: BiologicalSex | None = None
    height_cm: float | None = Field(default=None, ge=0)
    weight_kg: float | None = Field(default=None, ge=0)
    smoker: bool | None = None
    former_smoker: bool | None = None
    smoking_pack_years: float | None = Field(default=None, ge=0, le=200)
    years_since_quitting: int | None = Field(default=None, ge=0, le=100)
    alcohol_use: AlcoholUse | None = None
    activity_level: ActivityLevel | None = None
    postmenopausal: bool | None = None
    fragility_fracture_history: bool | None = None
    falls_last_year: int | None = Field(default=None, ge=0, le=50)
    feels_unsteady: bool | None = None
    sexually_active: bool | None = None
    new_or_multiple_partners: bool | None = None
    partner_with_sti: bool | None = None
    sex_with_men: bool | None = None
    sti_or_exposure_concerns: bool | None = None
    trying_to_conceive: bool | None = None
    currently_pregnant: bool | None = None
    taking_folic_acid: bool | None = None
    region_code: ItalianRegionCode | None = None
    occupation: str | None = Field(default=None, max_length=1000)
    relationship_label: str | None = Field(default=None, max_length=255)
    former_smoker: bool | None = None
    smoking_pack_years: float | None = Field(default=None, ge=0, le=200)
    years_since_quitting: int | None = Field(default=None, ge=0, le=100)
    alcohol_use: AlcoholUse | None = None
    activity_level: ActivityLevel | None = None
    postmenopausal: bool | None = None
    fragility_fracture_history: bool | None = None
    falls_last_year: int | None = Field(default=None, ge=0, le=50)
    feels_unsteady: bool | None = None
    sexually_active: bool | None = None
    new_or_multiple_partners: bool | None = None
    partner_with_sti: bool | None = None
    sex_with_men: bool | None = None
    sti_or_exposure_concerns: bool | None = None
    trying_to_conceive: bool | None = None
    currently_pregnant: bool | None = None
    taking_folic_acid: bool | None = None
    exercise_habits: str | None = Field(default=None, max_length=1000)
    sleep_pattern: str | None = Field(default=None, max_length=1000)
    symptom_triggers: str | None = Field(default=None, max_length=1000)
    functional_limitations: str | None = Field(default=None, max_length=1000)


class ManagedProfileCreateRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=255)
    last_name: str | None = Field(default=None, max_length=255)
    birth_date: date | None = None
    biological_sex: BiologicalSex | None = None
    region_code: ItalianRegionCode | None = None
    relationship_label: str | None = Field(default=None, max_length=255)
    exercise_habits: str | None = Field(default=None, max_length=1000)
    sleep_pattern: str | None = Field(default=None, max_length=1000)
    symptom_triggers: str | None = Field(default=None, max_length=1000)
    functional_limitations: str | None = Field(default=None, max_length=1000)


class OnboardingCompleteRequest(BaseModel):
    health_data_consent: bool
    ai_external_consent: bool = False
    first_name: str = Field(min_length=1, max_length=255)
    last_name: str = Field(min_length=1, max_length=255)
    birth_date: date
    biological_sex: BiologicalSex
    height_cm: float | None = Field(default=None, ge=0)
    weight_kg: float | None = Field(default=None, ge=0)
    smoker: bool = False
    former_smoker: bool = False
    smoking_pack_years: float | None = Field(default=None, ge=0, le=200)
    years_since_quitting: int | None = Field(default=None, ge=0, le=100)
    alcohol_use: AlcoholUse | None = None
    activity_level: ActivityLevel | None = None
    postmenopausal: bool = False
    fragility_fracture_history: bool = False
    falls_last_year: int | None = Field(default=None, ge=0, le=50)
    feels_unsteady: bool = False
    sexually_active: bool | None = None
    new_or_multiple_partners: bool = False
    partner_with_sti: bool = False
    sex_with_men: bool = False
    sti_or_exposure_concerns: bool = False
    trying_to_conceive: bool = False
    currently_pregnant: bool = False
    taking_folic_acid: bool = False
    region_code: ItalianRegionCode | None = None
    occupation: str | None = Field(default=None, max_length=1000)
    exercise_habits: str | None = Field(default=None, max_length=1000)
    sleep_pattern: str | None = Field(default=None, max_length=1000)
    symptom_triggers: str | None = Field(default=None, max_length=1000)
    functional_limitations: str | None = Field(default=None, max_length=1000)


class AiPrivacyUpdateRequest(BaseModel):
    ai_external_consent: bool


class AllergyCreateRequest(BaseModel):
    allergen: str = Field(min_length=1, max_length=255)
    severity: AllergySeverity | None = None
    notes: str | None = None


class AllergyResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    allergen: str
    severity: AllergySeverity | None
    notes: str | None


class ConditionCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    diagnosis_date: date | None = None
    status: ConditionStatus | None = None
    notes: str | None = None


class ConditionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    diagnosis_date: date | None
    status: ConditionStatus | None
    notes: str | None


class MedicationCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    dosage: str | None = None
    frequency: str | None = None
    route: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    active: bool = True
    notes: str | None = None
    schedules: list[MedicationScheduleCreateRequest] = Field(default_factory=list)


class MedicationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    dosage: str | None
    frequency: str | None
    route: str | None
    start_date: date | None
    end_date: date | None
    active: bool
    notes: str | None
    schedules: list[MedicationScheduleResponse] = Field(default_factory=list)


class FamilyHistoryCreateRequest(BaseModel):
    relation: str = Field(min_length=1, max_length=255)
    condition_name: str = Field(min_length=1, max_length=255)
    notes: str | None = None


class FamilyHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    relation: str
    condition_name: str
    notes: str | None


class VaccinationRecordCreateRequest(BaseModel):
    vaccine_name: str = Field(min_length=1, max_length=255)
    administered_on: date | None = None
    dose_number: int | None = Field(default=None, ge=1, le=20)
    next_due_date: date | None = None
    provider_name: str | None = Field(default=None, max_length=255)
    notes: str | None = Field(default=None, max_length=2000)


class VaccinationRecordUpdateRequest(BaseModel):
    vaccine_name: str | None = Field(default=None, min_length=1, max_length=255)
    administered_on: date | None = None
    dose_number: int | None = Field(default=None, ge=1, le=20)
    next_due_date: date | None = None
    provider_name: str | None = Field(default=None, max_length=255)
    notes: str | None = Field(default=None, max_length=2000)


class VaccinationRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    vaccine_name: str
    administered_on: date | None
    dose_number: int | None
    next_due_date: date | None
    provider_name: str | None
    notes: str | None


class ClinicalEpisodeCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    summary: str | None = Field(default=None, max_length=5000)
    status: ConditionStatus | None = None
    onset_date: date | None = None
    resolved_date: date | None = None
    next_review_date: date | None = None
    notes: str | None = Field(default=None, max_length=5000)


class ClinicalEpisodeUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    summary: str | None = Field(default=None, max_length=5000)
    status: ConditionStatus | None = None
    onset_date: date | None = None
    resolved_date: date | None = None
    next_review_date: date | None = None
    notes: str | None = Field(default=None, max_length=5000)


class ClinicalEpisodeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    summary: str | None
    status: ConditionStatus | None
    onset_date: date | None
    resolved_date: date | None
    next_review_date: date | None
    notes: str | None


class ProfileBundleResponse(BaseModel):
    profile: PatientProfileResponse
    onboarding: OnboardingStatusResponse
    allergies: list[AllergyResponse]
    medical_conditions: list[ConditionResponse]
    medications: list[MedicationResponse]
    family_history: list[FamilyHistoryResponse]
    vaccinations: list[VaccinationRecordResponse] = Field(default_factory=list)
    clinical_episodes: list[ClinicalEpisodeResponse] = Field(default_factory=list)
    managed_profiles: list[PatientProfileResponse] = Field(default_factory=list)
