from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.daily_entries import SymptomEntryCreateRequest, SymptomEntryResponse
from app.services.daily_entry_service import DailyEntryService


router = APIRouter(prefix="/daily-entries", tags=["symptoms"])


@router.post("/{entry_id}/symptoms", response_model=SymptomEntryResponse, status_code=status.HTTP_201_CREATED)
def add_symptom(
    entry_id: UUID,
    payload: SymptomEntryCreateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DailyEntryService(db).add_symptom(user, entry_id, payload)

