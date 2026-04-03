from __future__ import annotations

from datetime import timedelta

from sqlalchemy import and_, delete, or_
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models.ai_summary import AiSummary
from app.models.audit_log import AuditLog
from app.models.password_reset_token import PasswordResetToken
from app.models.refresh_token import RefreshToken
from app.models.base import utcnow


class RetentionService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.settings = get_settings()

    def cleanup_all(self) -> dict[str, int]:
        results = {
            "password_reset_tokens": self.cleanup_password_reset_tokens(),
            "refresh_tokens": self.cleanup_refresh_tokens(),
            "audit_logs": self.cleanup_audit_logs(),
            "ai_summaries": self.cleanup_ai_summaries(),
        }
        self.db.commit()
        return results

    def cleanup_password_reset_tokens(self) -> int:
        now = utcnow()
        stmt = delete(PasswordResetToken).where(
            or_(
                PasswordResetToken.expires_at < now,
                PasswordResetToken.used_at.is_not(None),
            )
        )
        result = self.db.execute(stmt)
        return int(result.rowcount or 0)

    def cleanup_refresh_tokens(self) -> int:
        now = utcnow()
        revoked_cutoff = now - timedelta(days=self.settings.retention_refresh_tokens_days)
        stmt = delete(RefreshToken).where(
            or_(
                RefreshToken.expires_at < now,
                and_(
                    RefreshToken.revoked_at.is_not(None),
                    RefreshToken.revoked_at < revoked_cutoff,
                ),
            )
        )
        result = self.db.execute(stmt)
        return int(result.rowcount or 0)

    def cleanup_audit_logs(self) -> int:
        if self.settings.retention_audit_logs_days <= 0:
            return 0
        cutoff = utcnow() - timedelta(days=self.settings.retention_audit_logs_days)
        result = self.db.execute(delete(AuditLog).where(AuditLog.created_at < cutoff))
        return int(result.rowcount or 0)

    def cleanup_ai_summaries(self) -> int:
        if self.settings.retention_ai_summaries_days <= 0:
            return 0
        cutoff = utcnow() - timedelta(days=self.settings.retention_ai_summaries_days)
        result = self.db.execute(delete(AiSummary).where(AiSummary.created_at < cutoff))
        return int(result.rowcount or 0)
