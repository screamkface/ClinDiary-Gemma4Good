from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.alert import Alert
from app.models.daily_entry import DailyEntry
from app.models.enums import AlertSeverity, AlertStatus, TimelineEventType, TimelineSeverity
from app.models.user import User
from app.repositories.alert_repository import AlertRepository
from app.repositories.daily_entry_repository import DailyEntryRepository
from app.repositories.timeline_repository import TimelineRepository
from app.services.profile_context import resolve_user_profile
from app.rules.red_flags import RedFlagRuleEngine


class AlertService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.alert_repository = AlertRepository(db)
        self.daily_entry_repository = DailyEntryRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.rule_engine = RedFlagRuleEngine()

    def sync_entry_alerts(self, entry: DailyEntry) -> list[Alert]:
        return self.sync_recent_alerts(entry.patient_id, entry.entry_date)

    def sync_recent_alerts(self, patient_id, anchor_date) -> list[Alert]:
        recent_entries = self.daily_entry_repository.list_for_patient_between(
            patient_id,
            anchor_date - timedelta(days=3),
            anchor_date + timedelta(days=3),
        )
        synced: list[Alert] = []

        for entry in recent_entries:
            matches = self.rule_engine.evaluate(entry, recent_entries)
            for match in matches:
                alert = self.alert_repository.get_open_by_rule(
                    patient_id=entry.patient_id,
                    rule_code=match.rule_code,
                    source_type=match.source_type,
                    source_id=match.source_id,
                )
                if alert is None:
                    alert = Alert(
                        patient_id=entry.patient_id,
                        severity=match.severity,
                        alert_type=match.alert_type,
                        rule_code=match.rule_code,
                        title=match.title,
                        description=match.description,
                        status=AlertStatus.OPEN,
                        source_type=match.source_type,
                        source_id=match.source_id,
                        triggered_at=match.triggered_at,
                    )
                    self.alert_repository.add(alert)
                    self.db.flush()
                else:
                    alert.severity = match.severity
                    alert.alert_type = match.alert_type
                    alert.title = match.title
                    alert.description = match.description
                    alert.triggered_at = match.triggered_at
                    alert.status = AlertStatus.OPEN
                    alert.resolved_at = None
                    alert.resolution_notes = None

                self.timeline_repository.upsert_source_event(
                    patient_id=entry.patient_id,
                    source_type="alert",
                    source_id=alert.id,
                    event_type=TimelineEventType.AI_ALERT,
                    title=alert.title,
                    description=alert.description,
                    event_date=alert.triggered_at,
                    severity=self._timeline_severity(alert.severity),
                )
                synced.append(alert)

        return synced

    def list_alerts(self, user: User, *, status_filter: AlertStatus | None = None) -> list[Alert]:
        profile = self._require_profile(user)
        return self.alert_repository.list_for_patient(profile.id, status=status_filter)

    def resolve_alert(self, user: User, alert_id: UUID, resolution_notes: str | None = None) -> Alert:
        profile = self._require_profile(user)
        alert = self.alert_repository.get_for_patient(profile.id, alert_id)
        if alert is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")

        alert.status = AlertStatus.RESOLVED
        alert.resolved_at = utcnow()
        alert.resolution_notes = resolution_notes
        self.db.commit()
        self.db.refresh(alert)
        return alert

    @staticmethod
    def _timeline_severity(severity: AlertSeverity) -> TimelineSeverity:
        if severity == AlertSeverity.URGENCY:
            return TimelineSeverity.IMPORTANT
        if severity in {AlertSeverity.ATTENTION, AlertSeverity.CONTACT_DOCTOR}:
            return TimelineSeverity.ATTENTION
        return TimelineSeverity.INFO

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile
