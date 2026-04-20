from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.daily_entries import DailyEntryCreateRequest, DailyEntryResponse, DailyEntryUpdateRequest
from app.services.daily_entry_service import DailyEntryService


router = APIRouter(prefix="/daily-entries", tags=["daily_entries"])


@router.post("", response_model=DailyEntryResponse, status_code=status.HTTP_201_CREATED)
def create_daily_entry(
    payload: DailyEntryCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DailyEntryService(db).create_entry(user, payload)


@router.get("", response_model=list[DailyEntryResponse])
def list_daily_entries(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DailyEntryService(db).list_entries(user)


@router.get("/{entry_id}", response_model=DailyEntryResponse)
def get_daily_entry(
    entry_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DailyEntryService(db).get_entry(user, entry_id)


@router.put("/{entry_id}", response_model=DailyEntryResponse)
def update_daily_entry(
    entry_id: UUID,
    payload: DailyEntryUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DailyEntryService(db).update_entry(user, entry_id, payload)


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_daily_entry(
    entry_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    DailyEntryService(db).delete_entry(user, entry_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

