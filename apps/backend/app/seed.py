import base64
from datetime import date, time

from app.core.database import SessionLocal
from app.core.storage import get_storage_service
from app.core.security import hash_password, utcnow
from app.models.allergy import Allergy
from app.models.clinical_document import ClinicalDocument
from app.models.daily_entry import DailyEntry
from app.models.enums import (
    ActivityLevel,
    AlcoholUse,
    BiologicalSex,
    ClinicalDocumentType,
    DocumentParsedStatus,
)
from app.models.enums import TimelineEventType
from app.models.family_history import FamilyHistoryEntry
from app.models.medical_condition import MedicalCondition
from app.models.medication import Medication
from app.models.medication_log import MedicationLog
from app.models.medication_schedule import MedicationSchedule
from app.models.enums import MedicationLogStatus
from app.models.patient_profile import PatientProfile
from app.models.symptom_entry import SymptomEntry
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.models.user_onboarding import UserOnboardingStatus
from app.models.vital_sign_entry import VitalSignEntry
from app.services.notification_service import NotificationService
from app.services.billing_service import BillingService
from app.services.screening_service import ScreeningService


DEMO_EMAIL = "demo@clindiary.app"
LEGACY_DEMO_EMAIL = "demo@clindiary.local"
DEMO_PASSWORD = "ChangeMe123!"


def main() -> None:
    with SessionLocal() as db:
        BillingService(db).ensure_catalog_seeded()
        existing = db.query(User).filter(User.email.in_([DEMO_EMAIL, LEGACY_DEMO_EMAIL])).first()
        if existing:
            if existing.email != DEMO_EMAIL or not existing.password_hash:
                existing.email = DEMO_EMAIL
                existing.password_hash = hash_password(DEMO_PASSWORD)
                db.commit()
            return

        user = User(email=DEMO_EMAIL, password_hash=hash_password(DEMO_PASSWORD))
        profile = PatientProfile(
            first_name="Giulia",
            last_name="Rossi",
            birth_date=date(1990, 5, 11),
            biological_sex=BiologicalSex.FEMALE,
            height_cm=168,
            weight_kg=62,
            smoker=False,
            alcohol_use=AlcoholUse.OCCASIONAL,
            activity_level=ActivityLevel.MODERATE,
            occupation="Lavoro d'ufficio con periodi di stress elevato e molte ore seduta.",
            exercise_habits="Camminata veloce 4 volte a settimana e pilates 2 volte a settimana.",
            sleep_pattern="Di solito 7 ore per notte, ma il sonno peggiora nelle settimane piu stressanti.",
            symptom_triggers="Stress intenso e poche ore di sonno tendono a peggiorare la cefalea.",
            functional_limitations="Nelle giornate peggiori riduce l'attivita fisica e fa pause piu frequenti al lavoro.",
        )
        onboarding = UserOnboardingStatus(
            health_data_consent=True,
            consented_at=utcnow(),
            onboarding_completed_at=utcnow(),
        )
        user.profile = profile
        user.onboarding_status = onboarding
        db.add(user)
        db.flush()

        medication = Medication(
            patient_id=profile.id,
            name="Vitamina D",
            dosage="1000 UI",
            frequency="1/die",
            active=True,
        )
        medication.schedules.append(
            MedicationSchedule(
                scheduled_time=time(8, 0),
                instructions="Assunzione mattutina",
                active=True,
            )
        )
        db.add_all(
            [
                Allergy(patient_id=profile.id, allergen="Penicillina", notes="Rash in adolescenza"),
                MedicalCondition(patient_id=profile.id, name="Emicrania", notes="Follow-up annuale"),
                medication,
                FamilyHistoryEntry(
                    patient_id=profile.id,
                    relation="madre",
                    condition_name="ipertensione",
                ),
            ]
        )

        entry = DailyEntry(
            patient_id=profile.id,
            entry_date=date.today(),
            sleep_hours=7.5,
            sleep_quality=7,
            energy_level=6,
            mood_level=7,
            stress_level=4,
            hydration_level=6,
            general_pain=2,
            general_notes="Giornata stabile con lieve cefalea serale.",
        )
        db.add(entry)
        db.flush()
        db.add(
            SymptomEntry(
                daily_entry_id=entry.id,
                symptom_code="headache",
                severity=3,
                duration_minutes=90,
                body_location="frontale",
                metadata_json={"with_nausea": False},
            )
        )
        db.add(
            VitalSignEntry(
                daily_entry_id=entry.id,
                type="blood_pressure",
                value="118/74",
                unit="mmHg",
            )
        )
        db.flush()
        db.add(
            MedicationLog(
                medication_id=medication.id,
                scheduled_at=utcnow(),
                taken_at=utcnow(),
                status=MedicationLogStatus.TAKEN,
                notes="Dose demo confermata dal seed.",
            )
        )
        db.add(
            TimelineEvent(
                patient_id=profile.id,
                event_type=TimelineEventType.DAILY_ENTRY,
                source_type="daily_entry",
                source_id=entry.id,
                title="Check-up giornaliero demo",
                description="Entry iniziale di esempio caricata dal seed.",
                event_date=utcnow(),
            )
        )

        try:
            storage = get_storage_service()
            image_bytes = base64.b64decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aYl8AAAAASUVORK5CYII="
            )
            stored = storage.save_bytes(
                object_key=f"patients/{profile.id}/documents/demo-seed.png",
                data=image_bytes,
                content_type="image/png",
            )
            document = ClinicalDocument(
                patient_id=profile.id,
                title="Documento demo seed",
                document_type=ClinicalDocumentType.GENERIC_DOCUMENT,
                exam_date=date.today(),
                source="Seed demo",
                file_url=stored.object_key,
                original_filename="demo-seed.png",
                mime_type="image/png",
                file_size_bytes=stored.size_bytes,
                parsed_status=DocumentParsedStatus.PENDING,
            )
            db.add(document)
            db.flush()
            db.add(
                TimelineEvent(
                    patient_id=profile.id,
                    event_type=TimelineEventType.DOCUMENT_UPLOADED,
                    source_type="clinical_document",
                    source_id=document.id,
                    title="Documento demo caricato",
                    description="Documento seed pronto per il processing documentale.",
                    event_date=utcnow(),
                )
            )
        except Exception:
            pass

        ScreeningService(db).ensure_catalog_seeded()
        ScreeningService(db)._recompute_for_profile(profile.id, emit_notifications=False)
        NotificationService(db).list_notifications(user)
        db.commit()


if __name__ == "__main__":
    main()
