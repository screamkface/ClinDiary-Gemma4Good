from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.wearables import (
    WearableDailySummaryResponse,
    WearableDailySummarySyncRequest,
    WearableDailySummarySyncResponse,
)
from app.services.wearable_service import WearableService


router = APIRouter(prefix="/wearables", tags=["wearables"])


@router.post("/sync-daily", response_model=WearableDailySummarySyncResponse)
def sync_wearable_daily_summaries(
    payload: WearableDailySummarySyncRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return WearableService(db).sync_daily_summaries(user, payload)


@router.get("/daily-summaries", response_model=list[WearableDailySummaryResponse])
def list_wearable_daily_summaries(
    days: Annotated[int, Query(ge=1, le=90)] = 30,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return WearableService(db).list_recent_summaries(user, days=days)
