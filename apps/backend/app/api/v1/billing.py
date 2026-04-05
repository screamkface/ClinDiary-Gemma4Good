from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.billing import (
    BillingActivateRequest,
    BillingActivateResponse,
    BillingPlanResponse,
    BillingStatusResponse,
    UserSubscriptionResponse,
)
from app.services.billing_service import BillingService


router = APIRouter(prefix="/billing", tags=["billing"])


def _plan_response(plan) -> BillingPlanResponse:
    return BillingPlanResponse.model_validate(plan).model_copy(
        update={
            "feature_codes": sorted(
                {
                    link.feature_code
                    for link in plan.feature_links
                    if link.feature is not None
                }
            )
        }
    )


def _status_response(service: BillingService, user: User) -> BillingStatusResponse:
    status_snapshot = service.get_status(user)
    current_plan = _plan_response(status_snapshot.current_plan)
    active_subscription = (
        UserSubscriptionResponse.model_validate(status_snapshot.active_subscription).model_copy(
            update={"plan": current_plan}
        )
        if status_snapshot.active_subscription is not None
        else None
    )
    return BillingStatusResponse(
        current_plan=current_plan,
        available_plans=[_plan_response(plan) for plan in status_snapshot.available_plans],
        active_subscription=active_subscription,
        entitlement_codes=sorted(status_snapshot.entitlement_codes),
        has_active_paid_subscription=status_snapshot.active_subscription is not None,
        checkout_ready=False,
        hackathon_demo_mode=status_snapshot.hackathon_demo_mode,
    )


@router.get("/plans", response_model=list[BillingPlanResponse])
def list_billing_plans(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = BillingService(db)
    service.ensure_catalog_seeded()
    return [_plan_response(plan) for plan in service.get_status(user).available_plans]


@router.get("/me", response_model=BillingStatusResponse)
def get_billing_status(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return _status_response(BillingService(db), user)


@router.post("/dev/activate", response_model=BillingActivateResponse, status_code=status.HTTP_200_OK)
def activate_debug_plan(
    payload: BillingActivateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = BillingService(db)
    status_snapshot = service.activate_manual_subscription(user, payload.plan_code)
    _ = status_snapshot
    return BillingActivateResponse(
        message="Debug subscription updated",
        status=_status_response(service, user),
    )


@router.post("/dev/cancel", response_model=BillingActivateResponse, status_code=status.HTTP_200_OK)
def cancel_debug_plan(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = BillingService(db)
    service.cancel_manual_subscription(user)
    return BillingActivateResponse(
        message="Debug subscription canceled",
        status=_status_response(service, user),
    )
