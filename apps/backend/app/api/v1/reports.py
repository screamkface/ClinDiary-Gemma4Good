from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.reports import ReportGenerateRequest, ReportResponse
from app.services.report_service import ReportService


router = APIRouter(prefix="/reports", tags=["reports"])


@router.post("/generate", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def generate_report(
    payload: ReportGenerateRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = ReportService(db)
    report = service.generate_report(
        user,
        report_type=payload.report_type,
        reference_date=payload.reference_date,
    )
    return service.build_detail_response(user, report)


@router.get("/{report_id}", response_model=ReportResponse)
def get_report(
    report_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    service = ReportService(db)
    report = service.get_report(user, report_id)
    return service.build_detail_response(user, report)


@router.get("/{report_id}/content")
def get_report_content(
    report_id: UUID,
    token: Annotated[str, Query(min_length=16)],
    db: Annotated[Session, Depends(get_db)],
):
    service = ReportService(db)
    service.verify_download_token(report_id, token)
    report, content = service.get_report_content(report_id)
    return Response(
        content=content,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{report.title}.pdf"'},
    )
