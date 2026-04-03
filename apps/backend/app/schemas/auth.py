from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=32)


class TokenRefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=32)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=32)


class AccountDeletionRequest(BaseModel):
    confirmation_text: str = Field(min_length=3, max_length=64)


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirmRequest(BaseModel):
    token: str = Field(min_length=32)
    new_password: str = Field(min_length=8, max_length=128)


class AuthUserResponse(BaseModel):
    id: UUID
    email: EmailStr
    role: str
    onboarding_completed: bool
    health_data_consent: bool
    ai_external_consent: bool
    ai_external_consented_at: datetime | None = None
    auth_provider: str = "password"


class TokenPairResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_token_expires_at: datetime
    refresh_token_expires_at: datetime
    user: AuthUserResponse


class PasswordResetResponse(BaseModel):
    message: str
    preview_token: str | None = None
