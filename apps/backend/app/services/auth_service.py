from datetime import timedelta
import secrets
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.storage import get_storage_service
from app.core.security import (
    create_access_token,
    coerce_utc,
    create_jti,
    create_password_reset_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_token,
    utcnow,
    verify_password,
)
from app.models.dossier_share_link import DossierShareLink
from app.models.password_reset_token import PasswordResetToken
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.models.user_onboarding import UserOnboardingStatus
from app.models.patient_profile import PatientProfile
from app.repositories.document_repository import DocumentRepository
from app.repositories.profile_repository import ProfileRepository
from app.repositories.report_repository import ReportRepository
from app.repositories.user_repository import UserRepository
from app.services.audit_service import AuditService


settings = get_settings()

try:
    from google.auth.transport.requests import Request as GoogleRequest
    from google.oauth2 import id_token as google_id_token
except ImportError:  # pragma: no cover - optional dependency
    GoogleRequest = None
    google_id_token = None


class AuthService:
    _ACCOUNT_DELETION_CONFIRMATION_TEXT = "ELIMINA"

    def __init__(self, db: Session) -> None:
        self.db = db
        self.user_repository = UserRepository(db)
        self.profile_repository = ProfileRepository(db)
        self.document_repository = DocumentRepository(db)
        self.report_repository = ReportRepository(db)
        self.audit_service = AuditService(db)
        self.storage_service = get_storage_service()

    def register(self, *, email: str, password: str):
        if self.user_repository.get_by_email(email) is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

        user = User(email=email.lower(), password_hash=hash_password(password))
        user.profile = PatientProfile()
        user.onboarding_status = UserOnboardingStatus()
        self.user_repository.add(user)
        self.db.commit()
        self.db.refresh(user)
        token_response = self._issue_tokens(user, auth_provider="password")
        self.audit_service.log_for_user(
            user,
            event_type="user_registered",
            entity_type="user",
            entity_id=user.id,
            summary="Nuovo account registrato.",
        )
        self.db.commit()
        return token_response

    def login(self, *, email: str, password: str):
        user = self.user_repository.get_by_email(email)
        if user is None or not verify_password(password, user.password_hash):
            self.audit_service.log_event(
                actor_email=email.lower(),
                event_type="login_failed",
                entity_type="auth_session",
                summary="Tentativo di login non riuscito.",
                outcome="failure",
            )
            self.db.commit()
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

        self.user_repository.touch_last_login(user, utcnow())
        self.db.commit()
        token_response = self._issue_tokens(user, auth_provider="password")
        self.audit_service.log_for_user(
            user,
            event_type="login_succeeded",
            entity_type="auth_session",
            summary="Login completato con successo.",
        )
        self.db.commit()
        return token_response

    def login_with_google(self, *, id_token: str):
        claims = self._verify_google_id_token(id_token)
        email_claim = claims.get("email")
        subject_claim = claims.get("sub")
        if not email_claim or not subject_claim:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid Google token payload")
        email = str(email_claim).lower().strip()
        google_subject = str(subject_claim).strip()

        user = self.user_repository.get_by_google_subject(google_subject)
        linked_by_email = self.user_repository.get_by_email(email)

        if user is not None and linked_by_email is not None and user.id != linked_by_email.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Google account already linked to another ClinDiary account",
            )

        if user is None:
            user = linked_by_email

        created = False
        if user is None:
            user = User(
                email=email,
                google_subject=google_subject,
                password_hash=hash_password(secrets.token_urlsafe(32)),
            )
            user.profile = PatientProfile()
            user.onboarding_status = UserOnboardingStatus()
            self.user_repository.add(user)
            created = True
        else:
            if user.google_subject is None:
                user.google_subject = google_subject
            elif user.google_subject != google_subject:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Google account already linked to another ClinDiary account",
                )
            if user.email.lower() != email:
                conflict = self.user_repository.get_by_email(email)
                if conflict is not None and conflict.id != user.id:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="Google email already linked to another ClinDiary account",
                    )
                user.email = email

        self.user_repository.touch_last_login(user, utcnow())
        self.db.commit()
        token_response = self._issue_tokens(user, auth_provider="google")
        self.audit_service.log_for_user(
            user,
            event_type="google_login_succeeded" if not created else "google_account_created",
            entity_type="auth_session",
            summary=(
                "Login Google completato con successo."
                if not created
                else "Nuovo account ClinDiary creato con Google."
            ),
            metadata={"google_subject": google_subject},
        )
        self.db.commit()
        return token_response

    def refresh(self, *, refresh_token: str):
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

        jti = payload.get("jti")
        user_id = payload.get("sub")
        token_record = self.user_repository.get_refresh_token(jti)
        if (
            token_record is None
            or token_record.user_id != UUID(user_id)
            or token_record.revoked_at is not None
            or coerce_utc(token_record.expires_at) <= utcnow()
            or token_record.token_hash != hash_token(refresh_token)
        ):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token expired")

        user = self.user_repository.get_by_id(UUID(user_id))
        if user is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

        token_record.revoked_at = utcnow()
        token_record.last_used_at = utcnow()
        token_response = self._issue_tokens(
            user,
            auth_provider=getattr(token_record, "auth_provider", None) or "password",
        )
        new_payload = decode_token(token_response["refresh_token"])
        token_record.replaced_by_jti = new_payload["jti"]
        self.audit_service.log_for_user(
            user,
            event_type="refresh_token_rotated",
            entity_type="refresh_token",
            summary="Refresh token ruotato con successo.",
        )
        self.db.commit()
        return token_response

    def logout(self, *, refresh_token: str) -> None:
        try:
            payload = decode_token(refresh_token)
        except ValueError:
            return

        jti = payload.get("jti")
        token_record = self.user_repository.get_refresh_token(jti)
        if token_record is not None and token_record.revoked_at is None:
            token_record.revoked_at = utcnow()
            user = self.user_repository.get_by_id(token_record.user_id)
            if user is not None:
                self.audit_service.log_for_user(
                    user,
                    event_type="logout_succeeded",
                    entity_type="refresh_token",
                    summary="Logout completato.",
                )
            self.db.commit()

    def delete_account(self, *, user: User, confirmation_text: str) -> None:
        normalized_confirmation = confirmation_text.strip().upper()
        if normalized_confirmation != self._ACCOUNT_DELETION_CONFIRMATION_TEXT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Confirmation text mismatch",
            )

        profiles = self.profile_repository.list_profiles_by_user_id(user.id)
        self._delete_storage_objects_for_profiles(profiles)
        self.audit_service.log_for_user(
            user,
            event_type="account_deleted",
            entity_type="user",
            entity_id=user.id,
            summary="Account ClinDiary eliminato dall'utente.",
            metadata={"confirmation_text": self._ACCOUNT_DELETION_CONFIRMATION_TEXT},
        )
        for profile in profiles:
            self.db.delete(profile)
        self.db.flush()
        self.user_repository.delete(user)
        self.db.commit()

    def request_password_reset(self, *, email: str):
        user = self.user_repository.get_by_email(email)
        preview_token: str | None = None
        if user is not None:
            raw_token = create_password_reset_token()
            preview_token = raw_token if settings.password_reset_preview_enabled else None
            reset_token = PasswordResetToken(
                user_id=user.id,
                token_hash=hash_token(raw_token),
                expires_at=utcnow() + timedelta(minutes=settings.password_reset_ttl_minutes),
            )
            self.user_repository.add_password_reset_token(reset_token)
            self.audit_service.log_for_user(
                user,
                event_type="password_reset_requested",
                entity_type="password_reset",
                summary="Preparata procedura di reset password.",
            )
            self.db.commit()
        else:
            self.audit_service.log_event(
                actor_email=email.lower(),
                event_type="password_reset_requested",
                entity_type="password_reset",
                summary="Richiesta reset password per account non trovato.",
                outcome="ignored",
            )
            self.db.commit()

        return {
            "message": "If the account exists, a reset flow has been prepared.",
            "preview_token": preview_token,
        }

    def confirm_password_reset(self, *, token: str, new_password: str) -> None:
        token_record = self.user_repository.get_password_reset_token(hash_token(token))
        if (
            token_record is None
            or token_record.used_at is not None
            or coerce_utc(token_record.expires_at) <= utcnow()
        ):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset token")

        user = self.user_repository.get_by_id(token_record.user_id)
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

        user.password_hash = hash_password(new_password)
        token_record.used_at = utcnow()
        for refresh_token in user.refresh_tokens:
            refresh_token.revoked_at = utcnow()
        self.audit_service.log_for_user(
            user,
            event_type="password_reset_confirmed",
            entity_type="password_reset",
            summary="Password aggiornata tramite reset.",
        )
        self.db.commit()

    def _delete_storage_objects_for_profiles(self, profiles) -> None:
        for profile in profiles:
            for document in self.document_repository.list_for_patient(profile.id):
                self.storage_service.delete_bytes(document.file_url)

            for report in self.report_repository.list_all_for_patient(profile.id):
                self.storage_service.delete_bytes(report.file_url)

            share_links = list(
                self.db.scalars(select(DossierShareLink).where(DossierShareLink.patient_id == profile.id))
            )
            for share_link in share_links:
                self.storage_service.delete_bytes(share_link.object_key)

    def _issue_tokens(self, user: User, *, auth_provider: str = "password") -> dict:
        access_token, access_expires_at = create_access_token(
            user_id=user.id,
            email=user.email,
            role=user.role.value,
        )
        jti = create_jti()
        refresh_token, refresh_expires_at = create_refresh_token(
            user_id=user.id,
            email=user.email,
            jti=jti,
        )
        token_record = RefreshToken(
            user_id=user.id,
            jti=jti,
            auth_provider=auth_provider,
            token_hash=hash_token(refresh_token),
            expires_at=refresh_expires_at,
        )
        self.user_repository.add_refresh_token(token_record)
        self.db.commit()
        self.db.refresh(user)

        onboarding = user.onboarding_status
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "access_token_expires_at": access_expires_at,
            "refresh_token_expires_at": refresh_expires_at,
            "user": {
                "id": user.id,
                "email": user.email,
                "role": user.role.value,
                "onboarding_completed": onboarding.onboarding_completed_at is not None,
                "health_data_consent": onboarding.health_data_consent,
                "ai_external_consent": onboarding.ai_external_consent,
                "ai_external_consented_at": onboarding.ai_external_consented_at,
                "auth_provider": auth_provider,
            },
        }

    def _verify_google_id_token(self, token: str) -> dict:
        if GoogleRequest is None or google_id_token is None:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Google sign-in is not available in this environment",
            )
        client_id = (settings.google_oauth_client_id or "").strip()
        if not client_id:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Google sign-in non configurato sul backend",
            )

        try:
            claims = google_id_token.verify_oauth2_token(token, GoogleRequest(), audience=client_id)
        except Exception as exc:  # pragma: no cover - network/provider guard
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google token",
            ) from exc

        if str(claims.get("email_verified")).lower() != "true":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google account email not verified",
            )
        return claims
