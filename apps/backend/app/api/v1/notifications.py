from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.notifications import (
    NotificationDeviceRegistrationRequest,
    NotificationDeviceRegistrationResponse,
    NotificationDeliveryReportResponse,
    NotificationMarkReadResponse,
    NotificationPreferencesResponse,
    NotificationPreferencesUpdateRequest,
    NotificationResponse,
    NotificationTestDeliveryRequest,
)
from app.services.notification_service import NotificationService


router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return NotificationService(db).list_notifications(user)


@router.get("/preferences", response_model=NotificationPreferencesResponse)
def get_notification_preferences(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return NotificationService(db).get_preferences(user)


@router.put("/preferences", response_model=NotificationPreferencesResponse)
def update_notification_preferences(
    payload: NotificationPreferencesUpdateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return NotificationService(db).update_preferences(user, payload)


@router.post("/devices", response_model=NotificationDeviceRegistrationResponse)
def register_notification_device(
    payload: NotificationDeviceRegistrationRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return NotificationService(db).register_device(user, payload)


@router.post("/test-delivery", response_model=NotificationDeliveryReportResponse)
def send_notification_test_delivery(
    payload: NotificationTestDeliveryRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return NotificationService(db).send_test_delivery(user, payload)


@router.post("/{notification_id}/read", response_model=NotificationMarkReadResponse)
def mark_notification_read(
    notification_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return NotificationService(db).mark_read(user, notification_id)
