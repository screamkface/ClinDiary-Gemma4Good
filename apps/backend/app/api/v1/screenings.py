from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.security import utcnow
from app.models.user import User
from app.schemas.screenings import (
    PatientScreeningStatusResponse,
    ScreeningCatalogItemResponse,
    ScreeningMarkDoneRequest,
    ScreeningRecomputeResponse,
)
from app.services.screening_service import ScreeningService


router = APIRouter(prefix="/screenings", tags=["screenings"])


@router.get("/catalog", response_model=list[ScreeningCatalogItemResponse])
def list_catalog(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    region_code: Annotated[str | None, Query()] = None,
):
    return ScreeningService(db).list_catalog(user, region_code=region_code)


@router.get("/me", response_model=list[PatientScreeningStatusResponse])
def list_my_screenings(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    region_code: Annotated[str | None, Query()] = None,
):
    return ScreeningService(db).list_patient_screenings(user, region_code=region_code)


@router.post("/recompute", response_model=ScreeningRecomputeResponse)
def recompute_screenings(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    region_code: Annotated[str | None, Query()] = None,
):
    items = ScreeningService(db).recompute_patient_screenings(user, region_code=region_code)
    return ScreeningRecomputeResponse(generated_at=utcnow(), items=items)


@router.post("/{screening_id}/mark-done", response_model=PatientScreeningStatusResponse)
def mark_screening_done(
    screening_id: UUID,
    payload: ScreeningMarkDoneRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    region_code: Annotated[str | None, Query()] = None,
):
    return ScreeningService(db).mark_done(
        user,
        screening_id,
        done_date=payload.done_date,
        region_code=region_code,
    )


@router.delete(
    "/{screening_id}/current-year-completion",
    response_model=PatientScreeningStatusResponse,
)
def clear_screening_current_year_completion(
    screening_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    region_code: Annotated[str | None, Query()] = None,
):
    return ScreeningService(db).clear_current_year_completion(
        user,
        screening_id,
        region_code=region_code,
    )
