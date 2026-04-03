from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.devices import (
    DeviceLinkRequest,
    DeviceLinkResponse,
    DeviceMeasurementIngestRequest,
    DeviceMeasurementIngestResponse,
    DeviceOverviewResponse,
    DeviceSyncResponse,
)
from app.services.device_service import DeviceService


router = APIRouter(prefix="/devices", tags=["devices"])


@router.get("/overview", response_model=DeviceOverviewResponse)
def get_device_overview(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DeviceService(db).overview(user)


@router.post("/providers/{provider_code}/link", response_model=DeviceLinkResponse)
def link_device_provider(
    provider_code: str,
    payload: DeviceLinkRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DeviceService(db).link_provider(user, provider_code, payload)


@router.delete("/connections/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
def disconnect_device_provider(
    connection_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    DeviceService(db).disconnect_connection(user, connection_id)


@router.post("/connections/{connection_id}/sync", response_model=DeviceSyncResponse)
def sync_device_connection(
    connection_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DeviceService(db).sync_connection(user, connection_id)


@router.post(
    "/connections/{connection_id}/measurements",
    response_model=DeviceMeasurementIngestResponse,
)
def ingest_device_measurements(
    connection_id: UUID,
    payload: DeviceMeasurementIngestRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DeviceService(db).ingest_measurements(user, connection_id, payload)
