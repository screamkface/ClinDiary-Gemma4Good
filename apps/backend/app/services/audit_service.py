from __future__ import annotations

import json
from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session
from structlog.contextvars import get_contextvars

from app.models.audit_log import AuditLog
from app.models.user import User


class AuditService:
    def __init__(self, db: Session) -> None:
        self.db = db

    def log_event(
        self,
        *,
        actor_user_id: UUID | None = None,
        actor_email: str | None = None,
        patient_id: UUID | None = None,
        event_type: str,
        entity_type: str,
        entity_id: UUID | None = None,
        summary: str,
        outcome: str = "success",
        metadata: dict[str, Any] | None = None,
    ) -> AuditLog:
        context = get_contextvars()
        item = AuditLog(
            actor_user_id=actor_user_id,
            actor_email=actor_email,
            patient_id=patient_id,
            request_id=str(context.get("request_id")) if context.get("request_id") else None,
            event_type=event_type,
            entity_type=entity_type,
            entity_id=entity_id,
            outcome=outcome,
            summary=summary,
            metadata_json=_serialize_metadata(metadata),
        )
        self.db.add(item)
        return item

    def log_for_user(
        self,
        user: User,
        *,
        event_type: str,
        entity_type: str,
        entity_id: UUID | None = None,
        summary: str,
        outcome: str = "success",
        metadata: dict[str, Any] | None = None,
    ) -> AuditLog:
        patient_id = getattr(getattr(user, "profile", None), "id", None)
        return self.log_event(
            actor_user_id=user.id,
            actor_email=user.email,
            patient_id=patient_id,
            event_type=event_type,
            entity_type=entity_type,
            entity_id=entity_id,
            summary=summary,
            outcome=outcome,
            metadata=metadata,
        )


def _serialize_metadata(metadata: dict[str, Any] | None) -> str | None:
    if not metadata:
        return None
    return json.dumps(metadata, ensure_ascii=True, default=str, sort_keys=True)
