from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.medications import (
    MedicationDetailResponse,
    MedicationLogCreateRequest,
    MedicationLogResponse,
    MedicationScheduleCreateRequest,
    MedicationSchedulePauseRequest,
    MedicationScheduleUpdateRequest,
    MedicationUpdateRequest,
)
from app.services.medication_adherence_service import MedicationAdherenceService
from app.services.medication_management_service import MedicationManagementService


router = APIRouter(prefix="/medications", tags=["medications"])


@router.get("/logs", response_model=list[MedicationLogResponse])
def list_medication_logs(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return MedicationAdherenceService(db).list_logs(user)


@router.post("/{medication_id}/log", response_model=MedicationLogResponse, status_code=status.HTTP_201_CREATED)
def log_medication(
    medication_id: UUID,
    payload: MedicationLogCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return MedicationAdherenceService(db).log_medication(user, medication_id, payload)


@router.put("/{medication_id}", response_model=MedicationDetailResponse)
def update_medication(
    medication_id: UUID,
    payload: MedicationUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return MedicationManagementService(db).update_medication(user, medication_id, payload)


@router.post(
    "/{medication_id}/schedules",
    response_model=MedicationDetailResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_schedule(
    medication_id: UUID,
    payload: MedicationScheduleCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return MedicationManagementService(db).add_schedule(user, medication_id, payload)


@router.put(
    "/{medication_id}/schedules/{schedule_id}",
    response_model=MedicationDetailResponse,
)
def update_schedule(
    medication_id: UUID,
    schedule_id: UUID,
    payload: MedicationScheduleUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return MedicationManagementService(db).update_schedule(user, medication_id, schedule_id, payload)


@router.post(
    "/{medication_id}/schedules/{schedule_id}/pause",
    response_model=MedicationDetailResponse,
)
def pause_schedule(
    medication_id: UUID,
    schedule_id: UUID,
    payload: MedicationSchedulePauseRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return MedicationManagementService(db).pause_schedule(
        user,
        medication_id,
        schedule_id,
        paused_until=payload.paused_until,
    )


@router.post(
    "/{medication_id}/schedules/{schedule_id}/resume",
    response_model=MedicationDetailResponse,
)
def resume_schedule(
    medication_id: UUID,
    schedule_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return MedicationManagementService(db).resume_schedule(user, medication_id, schedule_id)


@router.delete("/{medication_id}/schedules/{schedule_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_schedule(
    medication_id: UUID,
    schedule_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    MedicationManagementService(db).delete_schedule(user, medication_id, schedule_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
