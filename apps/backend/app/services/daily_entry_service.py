from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.daily_entry import DailyEntry
from app.models.enums import TimelineEventType
from app.models.symptom_entry import SymptomEntry
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.models.vital_sign_entry import VitalSignEntry
from app.services.profile_context import resolve_user_profile
from app.services.alert_service import AlertService
from app.repositories.daily_entry_repository import DailyEntryRepository
from app.repositories.timeline_repository import TimelineRepository


class DailyEntryService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.daily_entry_repository = DailyEntryRepository(db)
        self.timeline_repository = TimelineRepository(db)

    def create_entry(self, user: User, payload) -> DailyEntry:
        profile = self._require_profile(user)
        existing = self.daily_entry_repository.get_by_date(profile.id, payload.entry_date)
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A daily entry already exists for this date",
            )

        entry = DailyEntry(patient_id=profile.id, **payload.model_dump())
        self.daily_entry_repository.add(entry)
        self.db.flush()
        self.timeline_repository.upsert_source_event(
            patient_id=profile.id,
            source_type="daily_entry",
            source_id=entry.id,
            event_type=TimelineEventType.DAILY_ENTRY,
            title="Check-up giornaliero completato",
            description=self._describe_daily_entry(entry),
            event_date=utcnow(),
        )
        AlertService(self.db).sync_entry_alerts(entry)
        self.db.commit()
        self.db.refresh(entry)
        return self.daily_entry_repository.get_for_patient(profile.id, entry.id) or entry

    def list_entries(self, user: User):
        profile = self._require_profile(user)
        return self.daily_entry_repository.list_for_patient(profile.id)

    def get_entry(self, user: User, entry_id):
        profile = self._require_profile(user)
        entry = self.daily_entry_repository.get_for_patient(profile.id, entry_id)
        if entry is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Daily entry not found")
        return entry

    def update_entry(self, user: User, entry_id, payload):
        entry = self.get_entry(user, entry_id)
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(entry, field, value)

        self.timeline_repository.upsert_source_event(
            patient_id=entry.patient_id,
            source_type="daily_entry",
            source_id=entry.id,
            event_type=TimelineEventType.DAILY_ENTRY,
            title="Check-up giornaliero aggiornato",
            description=self._describe_daily_entry(entry),
            event_date=utcnow(),
        )
        AlertService(self.db).sync_entry_alerts(entry)
        self.db.commit()
        self.db.refresh(entry)
        return self.get_entry(user, entry.id)

    def add_symptom(self, user: User, entry_id, payload) -> SymptomEntry:
        entry = self.get_entry(user, entry_id)
        symptom = SymptomEntry(daily_entry_id=entry.id, **payload.model_dump())
        self.daily_entry_repository.add_symptom(symptom)
        self.db.flush()
        refreshed_entry = self.daily_entry_repository.get_for_patient(entry.patient_id, entry.id) or entry
        self.timeline_repository.add(
            TimelineEvent(
                patient_id=entry.patient_id,
                event_type=TimelineEventType.SYMPTOM_EVENT,
                source_type="symptom_entry",
                source_id=symptom.id,
                title=f"Sintomo registrato: {symptom.symptom_code}",
                description=f"Sintomo {symptom.symptom_code} aggiunto al diario giornaliero.",
                event_date=utcnow(),
            )
        )
        AlertService(self.db).sync_entry_alerts(refreshed_entry)
        self.db.commit()
        self.db.refresh(symptom)
        return symptom

    def add_vital(self, user: User, entry_id, payload) -> VitalSignEntry:
        entry = self.get_entry(user, entry_id)
        data = payload.model_dump()
        if data["measured_at"] is None:
            data["measured_at"] = utcnow()
        vital = VitalSignEntry(daily_entry_id=entry.id, **data)
        self.daily_entry_repository.add_vital(vital)
        self.db.flush()
        refreshed_entry = self.daily_entry_repository.get_for_patient(entry.patient_id, entry.id) or entry
        self.timeline_repository.add(
            TimelineEvent(
                patient_id=entry.patient_id,
                event_type=TimelineEventType.VITAL_EVENT,
                source_type="vital_sign_entry",
                source_id=vital.id,
                title=f"Parametro registrato: {vital.type}",
                description=f"{vital.type} registrato con valore {vital.value} {vital.unit or ''}".strip(),
                event_date=vital.measured_at,
            )
        )
        AlertService(self.db).sync_entry_alerts(refreshed_entry)
        self.db.commit()
        self.db.refresh(vital)
        return vital

    def _require_profile(self, user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    @staticmethod
    def _describe_daily_entry(entry: DailyEntry) -> str:
        parts: list[str] = []
        if entry.energy_level is not None:
            parts.append(f"energia {entry.energy_level}/10")
        if entry.mood_level is not None:
            parts.append(f"umore {entry.mood_level}/10")
        if entry.general_pain is not None:
            parts.append(f"dolore {entry.general_pain}/10")
        return ", ".join(parts) if parts else "Check-up giornaliero salvato."
