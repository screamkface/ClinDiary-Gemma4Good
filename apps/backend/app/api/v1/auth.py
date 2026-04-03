from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.auth import (
    AccountDeletionRequest,
    GoogleLoginRequest,
    LoginRequest,
    LogoutRequest,
    PasswordResetConfirmRequest,
    PasswordResetRequest,
    PasswordResetResponse,
    RegisterRequest,
    TokenPairResponse,
    TokenRefreshRequest,
)
from app.schemas.common import MessageResponse
from app.services.auth_service import AuthService


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenPairResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Annotated[Session, Depends(get_db)]):
    return AuthService(db).register(email=payload.email, password=payload.password)


@router.post("/login", response_model=TokenPairResponse)
def login(payload: LoginRequest, db: Annotated[Session, Depends(get_db)]):
    return AuthService(db).login(email=payload.email, password=payload.password)


@router.post("/google", response_model=TokenPairResponse)
def google_login(payload: GoogleLoginRequest, db: Annotated[Session, Depends(get_db)]):
    return AuthService(db).login_with_google(id_token=payload.id_token)


@router.post("/refresh", response_model=TokenPairResponse)
def refresh(payload: TokenRefreshRequest, db: Annotated[Session, Depends(get_db)]):
    return AuthService(db).refresh(refresh_token=payload.refresh_token)


@router.post("/logout", response_model=MessageResponse)
def logout(payload: LogoutRequest, db: Annotated[Session, Depends(get_db)]):
    AuthService(db).logout(refresh_token=payload.refresh_token)
    return MessageResponse(message="Session closed")


@router.post("/account/delete", response_model=MessageResponse)
def delete_account(
    payload: AccountDeletionRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    AuthService(db).delete_account(user=user, confirmation_text=payload.confirmation_text)
    return MessageResponse(message="Account deleted")


@router.post("/password-reset/request", response_model=PasswordResetResponse)
def request_password_reset(payload: PasswordResetRequest, db: Annotated[Session, Depends(get_db)]):
    return AuthService(db).request_password_reset(email=payload.email)


@router.post("/password-reset/confirm", response_model=MessageResponse)
def confirm_password_reset(
    payload: PasswordResetConfirmRequest,
    db: Annotated[Session, Depends(get_db)],
):
    AuthService(db).confirm_password_reset(token=payload.token, new_password=payload.new_password)
    return MessageResponse(message="Password updated")
