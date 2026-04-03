from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.profile import (
    AiPrivacyUpdateRequest,
    AllergyCreateRequest,
    AllergyResponse,
    ConditionCreateRequest,
    ConditionResponse,
    ClinicalEpisodeCreateRequest,
    ClinicalEpisodeResponse,
    ClinicalEpisodeUpdateRequest,
    FamilyHistoryCreateRequest,
    FamilyHistoryResponse,
    MedicationCreateRequest,
    MedicationResponse,
    ManagedProfileCreateRequest,
    OnboardingCompleteRequest,
    ProfileBundleResponse,
    PatientProfileResponse,
    ProfileUpdateRequest,
    VaccinationRecordCreateRequest,
    VaccinationRecordResponse,
    VaccinationRecordUpdateRequest,
)
from app.services.profile_service import ProfileService


router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("/me", response_model=ProfileBundleResponse)
def get_profile(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).get_bundle(user)


@router.put("/me", response_model=ProfileBundleResponse)
def update_profile(
    payload: ProfileUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).update_profile(user, payload)


@router.get("/profiles", response_model=list[PatientProfileResponse])
def list_profiles(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).list_profiles(user)


@router.post("/profiles", response_model=PatientProfileResponse, status_code=status.HTTP_201_CREATED)
def add_profile(
    payload: ManagedProfileCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).add_managed_profile(user, payload)


@router.post("/onboarding/complete", response_model=ProfileBundleResponse)
def complete_onboarding(
    payload: OnboardingCompleteRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).complete_onboarding(user, payload)


@router.patch("/privacy/ai", response_model=ProfileBundleResponse)
def update_ai_privacy(
    payload: AiPrivacyUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).update_ai_privacy(user, payload)


@router.get("/conditions", response_model=list[ConditionResponse])
def list_conditions(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).list_conditions(user)


@router.post("/conditions", response_model=ConditionResponse, status_code=status.HTTP_201_CREATED)
def add_condition(
    payload: ConditionCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).add_condition(user, payload)


@router.delete("/conditions/{condition_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_condition(
    condition_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    ProfileService(db).delete_condition(user, condition_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/allergies", response_model=list[AllergyResponse])
def list_allergies(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).list_allergies(user)


@router.post("/allergies", response_model=AllergyResponse, status_code=status.HTTP_201_CREATED)
def add_allergy(
    payload: AllergyCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).add_allergy(user, payload)


@router.delete("/allergies/{allergy_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_allergy(
    allergy_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    ProfileService(db).delete_allergy(user, allergy_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/medications", response_model=list[MedicationResponse])
def list_medications(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).list_medications(user)


@router.post("/medications", response_model=MedicationResponse, status_code=status.HTTP_201_CREATED)
def add_medication(
    payload: MedicationCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).add_medication(user, payload)


@router.delete("/medications/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_medication(
    medication_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    ProfileService(db).delete_medication(user, medication_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/family-history", response_model=list[FamilyHistoryResponse])
def list_family_history(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).list_family_history(user)


@router.post("/family-history", response_model=FamilyHistoryResponse, status_code=status.HTTP_201_CREATED)
def add_family_history(
    payload: FamilyHistoryCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).add_family_history(user, payload)


@router.delete("/family-history/{family_history_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_family_history(
    family_history_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    ProfileService(db).delete_family_history(user, family_history_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/vaccinations", response_model=list[VaccinationRecordResponse])
def list_vaccinations(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).list_vaccinations(user)


@router.post("/vaccinations", response_model=VaccinationRecordResponse, status_code=status.HTTP_201_CREATED)
def add_vaccination(
    payload: VaccinationRecordCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).add_vaccination(user, payload)


@router.put("/vaccinations/{vaccination_id}", response_model=VaccinationRecordResponse)
def update_vaccination(
    vaccination_id: UUID,
    payload: VaccinationRecordUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).update_vaccination(user, vaccination_id, payload)


@router.delete("/vaccinations/{vaccination_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_vaccination(
    vaccination_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    ProfileService(db).delete_vaccination(user, vaccination_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/problems", response_model=list[ClinicalEpisodeResponse])
def list_clinical_episodes(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).list_clinical_episodes(user)


@router.post("/problems", response_model=ClinicalEpisodeResponse, status_code=status.HTTP_201_CREATED)
def add_clinical_episode(
    payload: ClinicalEpisodeCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).add_clinical_episode(user, payload)


@router.put("/problems/{episode_id}", response_model=ClinicalEpisodeResponse)
def update_clinical_episode(
    episode_id: UUID,
    payload: ClinicalEpisodeUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return ProfileService(db).update_clinical_episode(user, episode_id, payload)


@router.delete("/problems/{episode_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_clinical_episode(
    episode_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    ProfileService(db).delete_clinical_episode(user, episode_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
