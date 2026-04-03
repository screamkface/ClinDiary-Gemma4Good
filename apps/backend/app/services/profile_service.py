from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.allergy import Allergy
from app.models.clinical_episode import ClinicalEpisode
from app.models.enums import TimelineEventType
from app.models.family_history import FamilyHistoryEntry
from app.models.medical_condition import MedicalCondition
from app.models.medication import Medication
from app.models.medication_schedule import MedicationSchedule
from app.models.patient_profile import PatientProfile
from app.models.vaccination_record import VaccinationRecord
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.repositories.profile_repository import ProfileRepository
from app.repositories.timeline_repository import TimelineRepository
from app.services.audit_service import AuditService
from app.services.notification_service import NotificationService


class ProfileService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.profile_repository = ProfileRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.audit_service = AuditService(db)

    def get_bundle(self, user: User):
        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)
        return {
            "profile": profile,
            "onboarding": onboarding,
            "allergies": list(profile.allergies),
            "medical_conditions": list(profile.conditions),
            "medications": list(profile.medications),
            "family_history": list(profile.family_history_entries),
            "vaccinations": self.profile_repository.list_vaccinations(profile.id),
            "clinical_episodes": self.profile_repository.list_clinical_episodes(profile.id),
            "managed_profiles": self.profile_repository.list_profiles_by_user_id(user.id),
        }

    def complete_onboarding(self, user: User, payload):
        if not payload.health_data_consent:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Health data consent is required",
            )

        profile = self._require_profile(user)
        onboarding = self._require_onboarding(user)

        normalized_payload = self._normalize_profile_payload(payload.model_dump())
        for field, value in normalized_payload.items():
            if hasattr(profile, field):
                setattr(profile, field, value)

        onboarding.health_data_consent = True
        onboarding.consented_at = utcnow()
        onboarding.ai_external_consent = payload.ai_external_consent
        if payload.ai_external_consent:
            onboarding.ai_external_consented_at = utcnow()
        onboarding.onboarding_completed_at = utcnow()

        self.timeline_repository.add(
            TimelineEvent(
                patient_id=profile.id,
                event_type=TimelineEventType.PROFILE_UPDATED,
                source_type="patient_profile",
                source_id=profile.id,
                title="Onboarding clinico completato",
                description="Profilo iniziale e consenso dati sanitari completati.",
                event_date=utcnow(),
            )
        )
        self.audit_service.log_for_user(
            user,
            event_type="onboarding_completed",
            entity_type="patient_profile",
            entity_id=profile.id,
            summary="Onboarding clinico completato.",
            metadata=normalized_payload,
        )
        self.db.commit()
        self.db.refresh(profile)
        self.db.refresh(onboarding)
        self._refresh_profile_dependent_rules(profile.id)
        return self.get_bundle(user)

    def update_ai_privacy(self, user: User, payload):
        onboarding = self._require_onboarding(user)
        onboarding.ai_external_consent = payload.ai_external_consent
        if payload.ai_external_consent:
            onboarding.ai_external_consented_at = utcnow()

        self.audit_service.log_for_user(
            user,
            event_type="ai_privacy_updated",
            entity_type="user_onboarding_status",
            summary=(
                "Consenso ai provider AI esterni attivato."
                if payload.ai_external_consent
                else "Consenso ai provider AI esterni revocato."
            ),
            metadata=payload.model_dump(),
        )
        self.db.commit()
        self.db.refresh(onboarding)
        return self.get_bundle(user)

    def update_profile(self, user: User, payload):
        profile = self._require_profile(user)
        normalized_payload = self._normalize_profile_payload(
            payload.model_dump(exclude_unset=True)
        )
        for field, value in normalized_payload.items():
            setattr(profile, field, value)

        self.timeline_repository.upsert_source_event(
            patient_id=profile.id,
            source_type="patient_profile",
            source_id=profile.id,
            event_type=TimelineEventType.PROFILE_UPDATED,
            title="Profilo clinico aggiornato",
            description="Dati anagrafici e clinici di base aggiornati.",
            event_date=utcnow(),
        )
        self.audit_service.log_for_user(
            user,
            event_type="profile_updated",
            entity_type="patient_profile",
            entity_id=profile.id,
            summary="Profilo clinico aggiornato.",
            metadata=normalized_payload,
        )
        self.db.commit()
        self.db.refresh(profile)
        self._refresh_profile_dependent_rules(profile.id)
        return self.get_bundle(user)

    def list_profiles(self, user: User) -> list[PatientProfile]:
        return self.profile_repository.list_profiles_by_user_id(user.id)

    def add_managed_profile(self, user: User, payload) -> PatientProfile:
        primary_profile = self._require_primary_profile(user)
        payload_data = self._normalize_profile_payload(payload.model_dump())
        if payload_data.get("region_code") is None:
            payload_data["region_code"] = primary_profile.region_code
        if payload_data.get("last_name") is None:
            payload_data["last_name"] = primary_profile.last_name
        profile = PatientProfile(
            user_id=user.id,
            is_primary=False,
            **payload_data,
        )
        self.profile_repository.create_profile(profile)
        self.db.flush()
        self.audit_service.log_for_user(
            user,
            event_type="managed_profile_added",
            entity_type="patient_profile",
            entity_id=profile.id,
            summary=f"Profilo gestito aggiunto: {profile.first_name}",
            metadata=payload.model_dump(),
        )
        self.db.commit()
        self.db.refresh(profile)
        self._refresh_profile_dependent_rules(profile.id)
        return profile

    @staticmethod
    def _normalize_profile_payload(payload_data: dict) -> dict:
        normalized = dict(payload_data)
        smoker = normalized.get("smoker")
        former_smoker = normalized.get("former_smoker")
        if smoker is True:
            normalized["former_smoker"] = False
            normalized["years_since_quitting"] = None
        elif former_smoker is not True:
            normalized["years_since_quitting"] = None

        if normalized.get("sexually_active") is False:
            normalized["new_or_multiple_partners"] = False
            normalized["partner_with_sti"] = False
            normalized["sex_with_men"] = False
            normalized["sti_or_exposure_concerns"] = False

        biological_sex = normalized.get("biological_sex")
        biological_sex_value = getattr(biological_sex, "value", biological_sex)
        if biological_sex_value not in {None, "female"}:
            normalized["postmenopausal"] = False
            normalized["trying_to_conceive"] = False
            normalized["currently_pregnant"] = False
            normalized["taking_folic_acid"] = False

        if normalized.get("currently_pregnant") is True:
            normalized["trying_to_conceive"] = False

        return normalized

    def add_allergy(self, user: User, payload) -> Allergy:
        profile = self._require_profile(user)
        allergy = Allergy(patient_id=profile.id, **payload.model_dump())
        self.profile_repository.add_allergy(allergy)
        self.audit_service.log_for_user(
            user,
            event_type="allergy_added",
            entity_type="allergy",
            summary=f"Allergia registrata: {allergy.allergen}",
        )
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)
        self.db.refresh(allergy)
        return allergy

    def add_condition(self, user: User, payload) -> MedicalCondition:
        profile = self._require_profile(user)
        condition = MedicalCondition(patient_id=profile.id, **payload.model_dump())
        self.profile_repository.add_condition(condition)
        self.audit_service.log_for_user(
            user,
            event_type="condition_added",
            entity_type="medical_condition",
            summary=f"Condizione registrata: {condition.name}",
        )
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)
        self.db.refresh(condition)
        return condition

    def add_medication(self, user: User, payload) -> Medication:
        profile = self._require_profile(user)
        payload_data = payload.model_dump()
        schedules = payload_data.pop("schedules", [])
        medication = Medication(patient_id=profile.id, **payload_data)
        self.profile_repository.add_medication(medication)
        self.db.flush()
        for schedule in schedules:
            days_of_week = schedule.pop("days_of_week", [])
            medication.schedules.append(
                MedicationSchedule(
                    days_of_week_csv=",".join(str(day) for day in days_of_week) or None,
                    **schedule,
                )
            )
        self.timeline_repository.add(
            TimelineEvent(
                patient_id=profile.id,
                event_type=TimelineEventType.MEDICATION_STARTED
                if medication.active
                else TimelineEventType.MEDICATION_STOPPED,
                source_type="medication",
                source_id=medication.id,
                title=f"Farmaco registrato: {medication.name}",
                description=f"Terapia {medication.name} registrata nel profilo clinico.",
                event_date=utcnow(),
            )
        )
        self.audit_service.log_for_user(
            user,
            event_type="medication_added",
            entity_type="medication",
            entity_id=medication.id,
            summary=f"Terapia registrata: {medication.name}",
            metadata={"schedule_count": len(medication.schedules)},
        )
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)
        self.db.refresh(medication)
        return medication

    def add_family_history(self, user: User, payload) -> FamilyHistoryEntry:
        profile = self._require_profile(user)
        item = FamilyHistoryEntry(patient_id=profile.id, **payload.model_dump())
        self.profile_repository.add_family_history(item)
        self.audit_service.log_for_user(
            user,
            event_type="family_history_added",
            entity_type="family_history",
            summary=f"Familiarita registrata: {item.relation} - {item.condition_name}",
        )
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)
        self.db.refresh(item)
        return item

    def list_vaccinations(self, user: User):
        profile = self._require_profile(user)
        return self.profile_repository.list_vaccinations(profile.id)

    def add_vaccination(self, user: User, payload) -> VaccinationRecord:
        profile = self._require_profile(user)
        vaccination = VaccinationRecord(patient_id=profile.id, **payload.model_dump())
        self.profile_repository.add_vaccination(vaccination)
        self.audit_service.log_for_user(
            user,
            event_type="vaccination_added",
            entity_type="vaccination_record",
            entity_id=vaccination.id,
            summary=f"Vaccino registrato: {vaccination.vaccine_name}",
            metadata=payload.model_dump(),
        )
        self.db.commit()
        self.db.refresh(vaccination)
        return vaccination

    def list_clinical_episodes(self, user: User):
        profile = self._require_profile(user)
        return self.profile_repository.list_clinical_episodes(profile.id)

    def add_clinical_episode(self, user: User, payload) -> ClinicalEpisode:
        profile = self._require_profile(user)
        episode = ClinicalEpisode(patient_id=profile.id, **payload.model_dump())
        self.profile_repository.add_clinical_episode(episode)
        self.timeline_repository.add(
            TimelineEvent(
                patient_id=profile.id,
                event_type=TimelineEventType.PROFILE_UPDATED,
                source_type="clinical_episode",
                source_id=episode.id,
                title=f"Problema clinico registrato: {episode.title}",
                description=episode.summary or f"Problema clinico registrato: {episode.title}.",
                event_date=utcnow(),
            )
        )
        self.audit_service.log_for_user(
            user,
            event_type="clinical_episode_added",
            entity_type="clinical_episode",
            entity_id=episode.id,
            summary=f"Problema clinico registrato: {episode.title}",
            metadata=payload.model_dump(),
        )
        self.db.commit()
        self.db.refresh(episode)
        return episode

    def update_clinical_episode(
        self,
        user: User,
        episode_id: UUID,
        payload,
    ) -> ClinicalEpisode:
        profile = self._require_profile(user)
        episode = self._require_owned_resource(
            ClinicalEpisode,
            profile.id,
            episode_id,
            "Clinical episode not found",
        )
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(episode, field, value)
        self.timeline_repository.upsert_source_event(
            patient_id=profile.id,
            source_type="clinical_episode",
            source_id=episode.id,
            event_type=TimelineEventType.PROFILE_UPDATED,
            title=f"Problema clinico aggiornato: {episode.title}",
            description=episode.summary or f"Problema clinico aggiornato: {episode.title}.",
            event_date=utcnow(),
        )
        self.audit_service.log_for_user(
            user,
            event_type="clinical_episode_updated",
            entity_type="clinical_episode",
            entity_id=episode.id,
            summary=f"Problema clinico aggiornato: {episode.title}",
            metadata=payload.model_dump(exclude_unset=True),
        )
        self.db.commit()
        self.db.refresh(episode)
        return episode

    def delete_clinical_episode(self, user: User, episode_id: UUID) -> None:
        profile = self._require_profile(user)
        episode = self._require_owned_resource(
            ClinicalEpisode,
            profile.id,
            episode_id,
            "Clinical episode not found",
        )
        self.timeline_repository.upsert_source_event(
            patient_id=profile.id,
            source_type="clinical_episode",
            source_id=episode.id,
            event_type=TimelineEventType.PROFILE_UPDATED,
            title=f"Problema clinico rimosso: {episode.title}",
            description=f"Problema clinico rimosso dal dossier: {episode.title}.",
            event_date=utcnow(),
        )
        self.audit_service.log_for_user(
            user,
            event_type="clinical_episode_deleted",
            entity_type="clinical_episode",
            entity_id=episode.id,
            summary=f"Problema clinico rimosso: {episode.title}",
        )
        self.db.delete(episode)
        self.db.commit()

    def update_vaccination(self, user: User, vaccination_id: UUID, payload) -> VaccinationRecord:
        profile = self._require_profile(user)
        vaccination = self._require_owned_resource(
            VaccinationRecord,
            profile.id,
            vaccination_id,
            "Vaccination not found",
        )
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(vaccination, field, value)

        self.audit_service.log_for_user(
            user,
            event_type="vaccination_updated",
            entity_type="vaccination_record",
            entity_id=vaccination.id,
            summary=f"Vaccino aggiornato: {vaccination.vaccine_name}",
            metadata=payload.model_dump(exclude_unset=True),
        )
        self.db.commit()
        self.db.refresh(vaccination)
        return vaccination

    def delete_vaccination(self, user: User, vaccination_id: UUID) -> None:
        profile = self._require_profile(user)
        vaccination = self._require_owned_resource(
            VaccinationRecord,
            profile.id,
            vaccination_id,
            "Vaccination not found",
        )
        self.audit_service.log_for_user(
            user,
            event_type="vaccination_deleted",
            entity_type="vaccination_record",
            entity_id=vaccination.id,
            summary=f"Vaccino rimosso: {vaccination.vaccine_name}",
        )
        self.db.delete(vaccination)
        self.db.commit()

    def delete_allergy(self, user: User, allergy_id: UUID) -> None:
        profile = self._require_profile(user)
        allergy = self._require_owned_resource(Allergy, profile.id, allergy_id, "Allergy not found")
        self.audit_service.log_for_user(
            user,
            event_type="allergy_deleted",
            entity_type="allergy",
            entity_id=allergy.id,
            summary=f"Allergia rimossa: {allergy.allergen}",
        )
        self.db.delete(allergy)
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)

    def delete_condition(self, user: User, condition_id: UUID) -> None:
        profile = self._require_profile(user)
        condition = self._require_owned_resource(
            MedicalCondition,
            profile.id,
            condition_id,
            "Condition not found",
        )
        self.audit_service.log_for_user(
            user,
            event_type="condition_deleted",
            entity_type="medical_condition",
            entity_id=condition.id,
            summary=f"Patologia rimossa: {condition.name}",
        )
        self.db.delete(condition)
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)

    def delete_medication(self, user: User, medication_id: UUID) -> None:
        profile = self._require_profile(user)
        medication = self._require_owned_resource(
            Medication,
            profile.id,
            medication_id,
            "Medication not found",
        )
        self.timeline_repository.upsert_source_event(
            patient_id=profile.id,
            source_type="medication",
            source_id=medication.id,
            event_type=TimelineEventType.MEDICATION_STOPPED,
            title=f"Terapia rimossa: {medication.name}",
            description=f"La terapia {medication.name} e stata rimossa dal profilo clinico.",
            event_date=utcnow(),
        )
        self.audit_service.log_for_user(
            user,
            event_type="medication_deleted",
            entity_type="medication",
            entity_id=medication.id,
            summary=f"Terapia rimossa: {medication.name}",
        )
        self.db.delete(medication)
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)

    def delete_family_history(self, user: User, family_history_id: UUID) -> None:
        profile = self._require_profile(user)
        item = self._require_owned_resource(
            FamilyHistoryEntry,
            profile.id,
            family_history_id,
            "Family history not found",
        )
        self.audit_service.log_for_user(
            user,
            event_type="family_history_deleted",
            entity_type="family_history",
            entity_id=item.id,
            summary=f"Familiarita rimossa: {item.relation} - {item.condition_name}",
        )
        self.db.delete(item)
        self.db.commit()
        self._refresh_profile_dependent_rules(profile.id)

    def list_allergies(self, user: User):
        profile = self._require_profile(user)
        return self.profile_repository.list_allergies(profile.id)

    def list_conditions(self, user: User):
        profile = self._require_profile(user)
        return self.profile_repository.list_conditions(profile.id)

    def list_medications(self, user: User):
        profile = self._require_profile(user)
        return self.profile_repository.list_medications(profile.id)

    def list_family_history(self, user: User):
        profile = self._require_profile(user)
        return self.profile_repository.list_family_history(profile.id)

    def _require_profile(self, user: User):
        active_profile = getattr(user, "active_profile", None)
        if active_profile is not None:
            return active_profile
        if user.profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return user.profile

    def _require_primary_profile(self, user: User):
        if user.profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return user.profile

    def _require_onboarding(self, user: User):
        if user.onboarding_status is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Onboarding not found")
        return user.onboarding_status

    def _require_owned_resource(self, model, patient_id, resource_id, detail: str):
        resource = self.db.get(model, resource_id)
        if resource is None or resource.patient_id != patient_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)
        return resource

    def _refresh_profile_dependent_rules(self, profile_id: UUID) -> None:
        # Riapplica le regole deterministiche che dipendono dal profilo
        # cosi screenings e notifiche restano allineati ai dati piu recenti.
        NotificationService(self.db).sync_patient_notifications(profile_id)
