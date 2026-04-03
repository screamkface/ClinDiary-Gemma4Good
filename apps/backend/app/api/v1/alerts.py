from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.enums import AlertStatus
from app.models.user import User
from app.schemas.alerts import AlertResolveRequest, AlertResponse
from app.services.alert_service import AlertService


router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("", response_model=list[AlertResponse])
def list_alerts(
    status_filter: Annotated[AlertStatus | None, Query(alias="status")] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return AlertService(db).list_alerts(user, status_filter=status_filter)


@router.post("/{alert_id}/resolve", response_model=AlertResponse)
def resolve_alert(
    alert_id: UUID,
    payload: AlertResolveRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return AlertService(db).resolve_alert(
        user,
        alert_id,
        resolution_notes=payload.resolution_notes,
    )
