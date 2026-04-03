from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.history import HistoryActivityDaysResponse, HistoryDayResponse
from app.services.history_service import HistoryService


router = APIRouter(prefix="/history", tags=["history"])


@router.get("/day", response_model=HistoryDayResponse)
def get_day_history(
    target_date: Annotated[date, Query()],
    include_rollups: Annotated[bool, Query()] = False,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return HistoryService(db).get_day_overview(
        user,
        target_date=target_date,
        include_rollups=include_rollups,
    )


@router.get("/activity-days", response_model=HistoryActivityDaysResponse)
def list_activity_days(
    start_date: Annotated[date, Query()],
    end_date: Annotated[date, Query()],
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return HistoryService(db).list_activity_dates(
        user,
        start_date=start_date,
        end_date=end_date,
    )
