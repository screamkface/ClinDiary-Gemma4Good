from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.dossier import (
    DossierImportRequest,
    DossierResponse,
    DossierShareCreateRequest,
    DossierShareLinkResponse,
)
from app.services.dossier_service import DossierService


router = APIRouter(prefix="/dossier", tags=["dossier"])


@router.get("", response_model=DossierResponse)
def get_dossier(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DossierService(db).get_dossier(user)


@router.get("/export")
def export_dossier(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    filename, content = DossierService(db).export_dossier(user)
    return Response(
        content=content,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        status_code=status.HTTP_200_OK,
    )


@router.get("/export/json")
def export_dossier_json(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    filename, content = DossierService(db).export_dossier_json(user)
    return Response(
        content=content,
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        status_code=status.HTTP_200_OK,
    )


@router.get("/export/emergency")
def export_emergency_dossier(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    filename, content = DossierService(db).export_emergency_dossier(user)
    return Response(
        content=content,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        status_code=status.HTTP_200_OK,
    )


@router.get("/share-links", response_model=list[DossierShareLinkResponse])
def list_share_links(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return [
        DossierShareLinkResponse(
            id=item.id,
            scope=item.scope,
            label=item.label,
            filename=item.filename,
            mime_type=item.mime_type,
            share_url=None,
            expires_at=item.expires_at,
            revoked_at=item.revoked_at,
            last_accessed_at=item.last_accessed_at,
            created_at=item.created_at,
        )
        for item in DossierService(db).list_share_links(user)
    ]


@router.post("/share-links", response_model=DossierShareLinkResponse, status_code=status.HTTP_201_CREATED)
def create_share_link(
    payload: DossierShareCreateRequest,
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    share_link, raw_token = DossierService(db).create_share_link(user, payload)
    share_url = str(request.url_for("get_shared_dossier", token=raw_token))
    return DossierShareLinkResponse(
        id=share_link.id,
        scope=share_link.scope,
        label=share_link.label,
        filename=share_link.filename,
        mime_type=share_link.mime_type,
        share_url=share_url,
        expires_at=share_link.expires_at,
        revoked_at=share_link.revoked_at,
        last_accessed_at=share_link.last_accessed_at,
        created_at=share_link.created_at,
    )


@router.delete("/share-links/{share_link_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_share_link(
    share_link_id: UUID,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    DossierService(db).revoke_share_link(user, share_link_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/share/{token}", name="get_shared_dossier")
def get_shared_dossier(
    token: str,
    db: Annotated[Session, Depends(get_db)],
):
    share_link, content = DossierService(db).get_shared_file(token)
    return Response(
        content=content,
        media_type=share_link.mime_type,
        headers={
            "Content-Disposition": f'attachment; filename="{share_link.filename}"',
            "Cache-Control": "no-store, max-age=0",
            "Pragma": "no-cache",
            "X-Content-Type-Options": "nosniff",
        },
        status_code=status.HTTP_200_OK,
    )


@router.post("/import", response_model=DossierResponse)
def import_dossier(
    payload: DossierImportRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return DossierService(db).import_dossier(user, payload)
