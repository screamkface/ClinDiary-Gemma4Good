from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.prevention_center import PreventionCenterResponse
from app.services.prevention_center_service import PreventionCenterService


router = APIRouter(prefix="/prevention-center", tags=["prevention-center"])


@router.get("", response_model=PreventionCenterResponse)
def get_prevention_center(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    region_code: Annotated[str | None, Query()] = None,
):
    return PreventionCenterService(db).get_center(user, region_code=region_code)
