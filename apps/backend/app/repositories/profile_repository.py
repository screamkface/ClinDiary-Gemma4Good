from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.allergy import Allergy
from app.models.clinical_episode import ClinicalEpisode
from app.models.family_history import FamilyHistoryEntry
from app.models.medical_condition import MedicalCondition
from app.models.medication import Medication
from app.models.patient_profile import PatientProfile
from app.models.user import User
from app.models.vaccination_record import VaccinationRecord
from app.models.user_onboarding import UserOnboardingStatus


class ProfileRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_profile_by_user_id(self, user_id: UUID) -> PatientProfile | None:
        stmt = (
            select(PatientProfile)
            .options(
                joinedload(PatientProfile.allergies),
                joinedload(PatientProfile.conditions),
                joinedload(PatientProfile.medications).joinedload(Medication.schedules),
                joinedload(PatientProfile.family_history_entries),
                joinedload(PatientProfile.vaccination_records),
                joinedload(PatientProfile.clinical_episodes),
            )
            .where(PatientProfile.user_id == user_id, PatientProfile.is_primary.is_(True))
        )
        return self.db.execute(stmt).unique().scalar_one_or_none()

    def list_profiles_by_user_id(self, user_id: UUID) -> list[PatientProfile]:
        stmt = (
            select(PatientProfile)
            .where(PatientProfile.user_id == user_id)
            .order_by(PatientProfile.is_primary.desc(), PatientProfile.created_at.asc())
        )
        return list(self.db.scalars(stmt))

    def get_profile_by_patient_id(self, patient_id: UUID) -> PatientProfile | None:
        stmt = (
            select(PatientProfile)
            .options(
                joinedload(PatientProfile.user).joinedload(User.onboarding_status),
                joinedload(PatientProfile.allergies),
                joinedload(PatientProfile.conditions),
                joinedload(PatientProfile.medications).joinedload(Medication.schedules),
                joinedload(PatientProfile.family_history_entries),
                joinedload(PatientProfile.vaccination_records),
                joinedload(PatientProfile.clinical_episodes),
            )
            .where(PatientProfile.id == patient_id)
        )
        return self.db.execute(stmt).unique().scalar_one_or_none()

    def create_default_profile(self, user_id: UUID) -> PatientProfile:
        profile = PatientProfile(user_id=user_id, is_primary=True)
        self.db.add(profile)
        return profile

    def create_profile(self, profile: PatientProfile) -> PatientProfile:
        self.db.add(profile)
        return profile

    def create_default_onboarding(self, user_id: UUID) -> UserOnboardingStatus:
        onboarding = UserOnboardingStatus(user_id=user_id)
        self.db.add(onboarding)
        return onboarding

    def list_patient_ids(self) -> list[UUID]:
        stmt = select(PatientProfile.id)
        return list(self.db.scalars(stmt))

    def get_onboarding_by_user_id(self, user_id: UUID) -> UserOnboardingStatus | None:
        stmt = select(UserOnboardingStatus).where(UserOnboardingStatus.user_id == user_id)
        return self.db.scalar(stmt)

    def list_allergies(self, patient_id: UUID) -> list[Allergy]:
        stmt = select(Allergy).where(Allergy.patient_id == patient_id).order_by(Allergy.created_at.desc())
        return list(self.db.scalars(stmt))

    def add_allergy(self, allergy: Allergy) -> Allergy:
        self.db.add(allergy)
        return allergy

    def list_conditions(self, patient_id: UUID) -> list[MedicalCondition]:
        stmt = (
            select(MedicalCondition)
            .where(MedicalCondition.patient_id == patient_id)
            .order_by(MedicalCondition.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def add_condition(self, condition: MedicalCondition) -> MedicalCondition:
        self.db.add(condition)
        return condition

    def list_medications(self, patient_id: UUID) -> list[Medication]:
        stmt = (
            select(Medication)
            .options(joinedload(Medication.schedules))
            .where(Medication.patient_id == patient_id)
            .order_by(Medication.created_at.desc())
        )
        return list(self.db.scalars(stmt).unique())

    def add_medication(self, medication: Medication) -> Medication:
        self.db.add(medication)
        return medication

    def list_family_history(self, patient_id: UUID) -> list[FamilyHistoryEntry]:
        stmt = (
            select(FamilyHistoryEntry)
            .where(FamilyHistoryEntry.patient_id == patient_id)
            .order_by(FamilyHistoryEntry.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def add_family_history(self, item: FamilyHistoryEntry) -> FamilyHistoryEntry:
        self.db.add(item)
        return item

    def list_vaccinations(self, patient_id: UUID) -> list[VaccinationRecord]:
        stmt = (
            select(VaccinationRecord)
            .where(VaccinationRecord.patient_id == patient_id)
            .order_by(VaccinationRecord.administered_on.desc(), VaccinationRecord.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def add_vaccination(self, item: VaccinationRecord) -> VaccinationRecord:
        self.db.add(item)
        return item

    def list_clinical_episodes(self, patient_id: UUID) -> list[ClinicalEpisode]:
        stmt = (
            select(ClinicalEpisode)
            .where(ClinicalEpisode.patient_id == patient_id)
            .order_by(ClinicalEpisode.status.desc().nullslast(), ClinicalEpisode.created_at.desc())
        )
        return list(self.db.scalars(stmt))

    def add_clinical_episode(self, item: ClinicalEpisode) -> ClinicalEpisode:
        self.db.add(item)
        return item
