from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from uuid import UUID

import jwt
from jwt import InvalidTokenError
from passlib.context import CryptContext

from app.core.config import get_settings


pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
settings = get_settings()


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def coerce_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_access_token(*, user_id: UUID, email: str, role: str) -> tuple[str, datetime]:
    expires_at = utcnow() + timedelta(minutes=settings.access_token_ttl_minutes)
    payload = {
        "sub": str(user_id),
        "email": email,
        "role": role,
        "type": "access",
        "exp": expires_at,
        "iat": utcnow(),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm), expires_at


def create_refresh_token(*, user_id: UUID, email: str, jti: str) -> tuple[str, datetime]:
    expires_at = utcnow() + timedelta(days=settings.refresh_token_ttl_days)
    payload = {
        "sub": str(user_id),
        "email": email,
        "jti": jti,
        "type": "refresh",
        "exp": expires_at,
        "iat": utcnow(),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm), expires_at


def create_document_view_token(*, document_id: UUID, user_id: UUID) -> tuple[str, datetime]:
    expires_at = utcnow() + timedelta(minutes=settings.viewer_url_ttl_minutes)
    payload = {
        "sub": str(user_id),
        "document_id": str(document_id),
        "type": "document_view",
        "exp": expires_at,
        "iat": utcnow(),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm), expires_at


def create_report_download_token(*, report_id: UUID, user_id: UUID) -> tuple[str, datetime]:
    expires_at = utcnow() + timedelta(minutes=settings.viewer_url_ttl_minutes)
    payload = {
        "sub": str(user_id),
        "report_id": str(report_id),
        "type": "report_download",
        "exp": expires_at,
        "iat": utcnow(),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm), expires_at


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except InvalidTokenError as exc:
        raise ValueError("Invalid token") from exc


def create_password_reset_token() -> str:
    return secrets.token_urlsafe(48)


def create_jti() -> str:
    return secrets.token_urlsafe(32)
