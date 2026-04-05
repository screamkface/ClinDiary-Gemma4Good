from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.insights import (
    InsightSummaryResponse,
    LocalInsightRuntimeStatusResponse,
    OnDeviceInsightPromptResponse,
)
from app.services.insight_service import InsightService


router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("/daily", response_model=InsightSummaryResponse)
def get_daily_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).get_daily_summary(user, reference_date)


@router.post("/daily/regenerate", response_model=InsightSummaryResponse)
def regenerate_daily_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).regenerate_daily_summary(user, reference_date)


@router.get("/daily/private-local", response_model=InsightSummaryResponse)
def get_private_local_daily_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).get_private_local_daily_summary(user, reference_date)


@router.get("/daily/on-device-prompt", response_model=OnDeviceInsightPromptResponse)
def get_on_device_daily_prompt(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).get_on_device_daily_recap_prompt(user, reference_date)


@router.post("/daily/private-local/regenerate", response_model=InsightSummaryResponse)
def regenerate_private_local_daily_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).regenerate_private_local_daily_summary(user, reference_date)


@router.get("/local-status", response_model=LocalInsightRuntimeStatusResponse)
def get_local_insight_status(
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    _ = user
    return InsightService(db).get_private_local_runtime_status()


@router.get("/weekly", response_model=InsightSummaryResponse)
def get_weekly_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).get_weekly_summary(user, reference_date)


@router.post("/weekly/regenerate", response_model=InsightSummaryResponse)
def regenerate_weekly_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).regenerate_weekly_summary(user, reference_date)


@router.get("/monthly", response_model=InsightSummaryResponse)
def get_monthly_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).get_monthly_summary(user, reference_date)


@router.post("/monthly/regenerate", response_model=InsightSummaryResponse)
def regenerate_monthly_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).regenerate_monthly_summary(user, reference_date)


@router.get("/pre-visit", response_model=InsightSummaryResponse)
def get_pre_visit_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).get_pre_visit_summary(user, reference_date)


@router.post("/pre-visit/regenerate", response_model=InsightSummaryResponse)
def regenerate_pre_visit_insight(
    reference_date: Annotated[date | None, Query()] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
    db: Annotated[Session, Depends(get_db)] = None,
):
    return InsightService(db).regenerate_pre_visit_summary(user, reference_date)
