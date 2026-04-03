from datetime import date, timedelta

from app.models.ai_summary import AiSummary
from app.models.audit_log import AuditLog
from app.models.enums import AiSummaryType, UserRole
from app.models.password_reset_token import PasswordResetToken
from app.models.patient_profile import PatientProfile
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.core.config import get_settings
from app.services.retention_service import RetentionService
from app.models.base import utcnow


def _seed_user_and_profile(db_session):
    user = User(
        email="retention@example.com",
        password_hash="hash",
        role=UserRole.PATIENT,
    )
    db_session.add(user)
    db_session.flush()
    profile = PatientProfile(
        user_id=user.id,
        is_primary=True,
        first_name="Anna",
        last_name="Rossi",
    )
    db_session.add(profile)
    db_session.flush()
    return user, profile


def test_retention_cleanup_removes_expired_tokens_and_old_records(db_session, monkeypatch):
    monkeypatch.setenv("RETENTION_AUDIT_LOGS_DAYS", "30")
    monkeypatch.setenv("RETENTION_AI_SUMMARIES_DAYS", "180")
    monkeypatch.setenv("RETENTION_REFRESH_TOKENS_DAYS", "15")
    get_settings.cache_clear()

    user, profile = _seed_user_and_profile(db_session)
    now = utcnow()

    db_session.add_all(
        [
            PasswordResetToken(
                user_id=user.id,
                token_hash="expired-token",
                expires_at=now - timedelta(days=1),
            ),
            PasswordResetToken(
                user_id=user.id,
                token_hash="used-token",
                expires_at=now + timedelta(days=1),
                used_at=now - timedelta(hours=1),
            ),
            RefreshToken(
                user_id=user.id,
                jti="expired-refresh",
                token_hash="hash-1",
                expires_at=now - timedelta(days=1),
            ),
            RefreshToken(
                user_id=user.id,
                jti="revoked-refresh",
                token_hash="hash-2",
                expires_at=now + timedelta(days=10),
                revoked_at=now - timedelta(days=20),
            ),
            AuditLog(
                actor_user_id=user.id,
                patient_id=profile.id,
                actor_email=user.email,
                event_type="profile_viewed",
                entity_type="profile",
                outcome="success",
                summary="Visualizzazione profilo",
                created_at=now - timedelta(days=45),
                updated_at=now - timedelta(days=45),
            ),
            AuditLog(
                actor_user_id=user.id,
                patient_id=profile.id,
                actor_email=user.email,
                event_type="profile_viewed",
                entity_type="profile",
                outcome="success",
                summary="Visualizzazione recente",
                created_at=now - timedelta(days=5),
                updated_at=now - timedelta(days=5),
            ),
            AiSummary(
                patient_id=profile.id,
                summary_type=AiSummaryType.MONTHLY,
                period_start=date(2025, 1, 1),
                period_end=date(2025, 1, 31),
                content="Vecchio recap",
                created_at=now - timedelta(days=240),
                updated_at=now - timedelta(days=240),
                generated_at=now - timedelta(days=240),
            ),
            AiSummary(
                patient_id=profile.id,
                summary_type=AiSummaryType.WEEKLY,
                period_start=date.today() - timedelta(days=7),
                period_end=date.today(),
                content="Recap recente",
                created_at=now - timedelta(days=3),
                updated_at=now - timedelta(days=3),
                generated_at=now - timedelta(days=3),
            ),
        ]
    )
    db_session.commit()

    results = RetentionService(db_session).cleanup_all()

    assert results == {
        "password_reset_tokens": 2,
        "refresh_tokens": 2,
        "audit_logs": 1,
        "ai_summaries": 1,
    }

    assert db_session.query(PasswordResetToken).count() == 0
    assert db_session.query(RefreshToken).count() == 0
    assert db_session.query(AuditLog).count() == 1
    assert db_session.query(AiSummary).count() == 1
    get_settings.cache_clear()


def test_retention_can_disable_ai_summary_cleanup(db_session, monkeypatch):
    monkeypatch.setenv("RETENTION_AI_SUMMARIES_DAYS", "0")
    get_settings.cache_clear()
    _, profile = _seed_user_and_profile(db_session)
    old_summary = AiSummary(
        patient_id=profile.id,
        summary_type=AiSummaryType.DAILY,
        period_start=date(2025, 1, 1),
        period_end=date(2025, 1, 1),
        content="Recap da mantenere",
        created_at=utcnow() - timedelta(days=400),
        updated_at=utcnow() - timedelta(days=400),
        generated_at=utcnow() - timedelta(days=400),
    )
    db_session.add(old_summary)
    db_session.commit()

    removed = RetentionService(db_session).cleanup_ai_summaries()

    assert removed == 0
    assert db_session.query(AiSummary).count() == 1
    get_settings.cache_clear()
