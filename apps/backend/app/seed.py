import base64
from datetime import date, time, timedelta

from app.core.database import SessionLocal
from app.core.security import hash_password, utcnow
from app.core.storage import get_storage_service
from app.models.alert import Alert
from app.models.allergy import Allergy
from app.models.clinical_document import ClinicalDocument
from app.models.daily_entry import DailyEntry
from app.models.enums import (
    ActivityLevel,
    AlcoholUse,
    AlertSeverity,
    BiologicalSex,
    ClinicalDocumentType,
    DocumentParsedStatus,
    ItalianRegionCode,
    MedicationLogStatus,
    TimelineEventType,
)
from app.models.family_history import FamilyHistoryEntry
from app.models.medical_condition import MedicalCondition
from app.models.medication import Medication
from app.models.medication_log import MedicationLog
from app.models.medication_schedule import MedicationSchedule
from app.models.patient_profile import PatientProfile
from app.models.symptom_entry import SymptomEntry
from app.models.timeline_event import TimelineEvent
from app.models.user import User
from app.models.user_onboarding import UserOnboardingStatus
from app.models.vital_sign_entry import VitalSignEntry
from app.models.wearable_daily_summary import WearableDailySummary
from app.services.billing_service import BillingService
from app.services.notification_service import NotificationService
from app.services.screening_service import ScreeningService


DEMO_EMAIL = "demo@clindiary.app"
LEGACY_DEMO_EMAIL = "demo@clindiary.local"
DEMO_PASSWORD = "ChangeMe123!"
_TINY_PNG_BASE64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aYl8AAAAASUVORK5CYII="
)


def main() -> None:
    with SessionLocal() as db:
        billing_service = BillingService(db)
        billing_service.ensure_catalog_seeded()
        _reset_existing_demo_users(db)

        user = User(email=DEMO_EMAIL, password_hash=hash_password(DEMO_PASSWORD))
        onboarding = UserOnboardingStatus(
            health_data_consent=True,
            consented_at=utcnow(),
            onboarding_completed_at=utcnow(),
            ai_external_consent=False,
        )
        user.onboarding_status = onboarding
        db.add(user)
        db.flush()

        profiles = [
            _build_profile(
                user_id=user.id,
                is_primary=True,
                first_name="Giulia",
                last_name="Rossi",
                relationship_label="Scenario A",
                birth_date=date(1990, 5, 11),
                biological_sex=BiologicalSex.FEMALE,
                height_cm=168,
                weight_kg=62,
                smoker=False,
                alcohol_use=AlcoholUse.OCCASIONAL,
                activity_level=ActivityLevel.MODERATE,
                occupation="Routine d'ufficio regolare, attività fisica costante e pochi sintomi.",
                exercise_habits="Camminata veloce 4 volte a settimana.",
                sleep_pattern="Sonno mediamente regolare tra 7 e 8 ore.",
                symptom_triggers="Stress intenso e poche ore di sonno possono far comparire lieve cefalea.",
                functional_limitations="Nessuna limitazione stabile.",
            ),
            _build_profile(
                user_id=user.id,
                is_primary=False,
                first_name="Elena",
                last_name="Rossi",
                relationship_label="Scenario B",
                birth_date=date(1988, 11, 2),
                biological_sex=BiologicalSex.FEMALE,
                height_cm=166,
                weight_kg=64,
                smoker=False,
                alcohol_use=AlcoholUse.NONE,
                activity_level=ActivityLevel.LIGHT,
                occupation="Settimana di lavoro intensa con sonno frammentato.",
                exercise_habits="Attività fisica ridotta negli ultimi giorni.",
                sleep_pattern="Dorme poco quando aumenta lo stress lavorativo.",
                symptom_triggers="Sonno scarso tende a peggiorare tosse e spossatezza.",
                functional_limitations="Riduce le attività serali nei giorni peggiori.",
            ),
            _build_profile(
                user_id=user.id,
                is_primary=False,
                first_name="Paolo",
                last_name="Rossi",
                relationship_label="Scenario C",
                birth_date=date(1979, 3, 18),
                biological_sex=BiologicalSex.MALE,
                height_cm=176,
                weight_kg=80,
                smoker=False,
                alcohol_use=AlcoholUse.OCCASIONAL,
                activity_level=ActivityLevel.MODERATE,
                occupation="Trasferte frequenti e connettività mobile non sempre stabile.",
                exercise_habits="Cammina molto durante i viaggi di lavoro.",
                sleep_pattern="Sonno variabile quando è fuori casa.",
                symptom_triggers="Routine irregolare e trasferte.",
                functional_limitations="Preferisce usare funzioni rapide quando è in mobilità.",
            ),
        ]

        db.add_all(profiles)
        db.flush()
        user.profile = profiles[0]

        _seed_scenario_a(db, profiles[0])
        _seed_scenario_b(db, profiles[1])
        _seed_scenario_c(db, profiles[2])

        screening_service = ScreeningService(db)
        screening_service.ensure_catalog_seeded()
        for profile in profiles:
            screening_service._recompute_for_profile(profile.id, emit_notifications=False)

        NotificationService(db).list_notifications(user)
        db.commit()


def _reset_existing_demo_users(db) -> None:
    existing_users = db.query(User).filter(User.email.in_([DEMO_EMAIL, LEGACY_DEMO_EMAIL])).all()
    for user in existing_users:
        db.delete(user)
    if existing_users:
        db.commit()


def _build_profile(
    *,
    user_id,
    is_primary: bool,
    first_name: str,
    last_name: str,
    relationship_label: str,
    birth_date: date,
    biological_sex: BiologicalSex,
    height_cm: float,
    weight_kg: float,
    smoker: bool,
    alcohol_use: AlcoholUse,
    activity_level: ActivityLevel,
    occupation: str,
    exercise_habits: str,
    sleep_pattern: str,
    symptom_triggers: str,
    functional_limitations: str,
) -> PatientProfile:
    return PatientProfile(
        user_id=user_id,
        is_primary=is_primary,
        first_name=first_name,
        last_name=last_name,
        relationship_label=relationship_label,
        birth_date=birth_date,
        biological_sex=biological_sex,
        height_cm=height_cm,
        weight_kg=weight_kg,
        smoker=smoker,
        alcohol_use=alcohol_use,
        activity_level=activity_level,
        region_code=ItalianRegionCode.CAM,
        occupation=occupation,
        exercise_habits=exercise_habits,
        sleep_pattern=sleep_pattern,
        symptom_triggers=symptom_triggers,
        functional_limitations=functional_limitations,
    )


def _seed_scenario_a(db, profile: PatientProfile) -> None:
    medication = _create_medication(
        profile=profile,
        name="Vitamina D",
        dosage="1000 UI",
        frequency="1/die",
        scheduled_time=time(8, 0),
        instructions="Assunzione mattutina regolare.",
    )
    db.add_all(
        [
            Allergy(patient_id=profile.id, allergen="Penicillina", notes="Rash in adolescenza"),
            MedicalCondition(patient_id=profile.id, name="Emicrania", notes="Follow-up annuale"),
            FamilyHistoryEntry(
                patient_id=profile.id,
                relation="madre",
                condition_name="ipertensione",
            ),
            medication,
        ]
    )
    db.flush()

    entries = [
        (
            date.today() - timedelta(days=2),
            dict(
                sleep_hours=7.8,
                sleep_quality=8,
                energy_level=7,
                mood_level=7,
                stress_level=3,
                hydration_level=7,
                general_pain=1,
                general_notes="Routine regolare e sintomi trascurabili.",
            ),
            None,
            ("blood_pressure", "118/74", "mmHg"),
            7820,
            438,
        ),
        (
            date.today() - timedelta(days=1),
            dict(
                sleep_hours=7.2,
                sleep_quality=7,
                energy_level=6,
                mood_level=7,
                stress_level=4,
                hydration_level=6,
                general_pain=2,
                general_notes="Lieve cefalea serale dopo una giornata intensa.",
            ),
            ("headache", 3, "frontale"),
            ("blood_pressure", "119/75", "mmHg"),
            8450,
            430,
        ),
        (
            date.today(),
            dict(
                sleep_hours=7.5,
                sleep_quality=7,
                energy_level=6,
                mood_level=7,
                stress_level=4,
                hydration_level=6,
                general_pain=2,
                general_notes="Giornata stabile con lieve tensione cervicale serale.",
            ),
            ("headache", 2, "cervicale"),
            ("blood_pressure", "117/73", "mmHg"),
            8010,
            425,
        ),
    ]
    for day, entry_payload, symptom_payload, vital_payload, steps, sleep_minutes in entries:
        entry = _create_daily_entry(db, profile=profile, entry_date=day, **entry_payload)
        if symptom_payload is not None:
            symptom_code, severity, body_location = symptom_payload
            db.add(
                SymptomEntry(
                    daily_entry_id=entry.id,
                    symptom_code=symptom_code,
                    severity=severity,
                    body_location=body_location,
                )
            )
        vital_type, value, unit = vital_payload
        db.add(
            VitalSignEntry(
                daily_entry_id=entry.id,
                type=vital_type,
                value=value,
                unit=unit,
                measured_at=_timestamp_for(day, 8, 15),
            )
        )
        db.add(
            MedicationLog(
                medication_id=medication.id,
                scheduled_at=_timestamp_for(day, 8, 0),
                taken_at=_timestamp_for(day, 8, 5),
                status=MedicationLogStatus.TAKEN,
                notes="Dose registrata automaticamente dal seed hackathon.",
            )
        )
        db.add(
            WearableDailySummary(
                patient_id=profile.id,
                summary_date=day,
                source_platform="android",
                source_name="Health Connect",
                steps_count=steps,
                sleep_minutes=sleep_minutes,
                heart_rate_avg_bpm=74,
                record_count=12,
                synced_at=_timestamp_for(day, 22, 0),
            )
        )

    _add_demo_document(
        db,
        profile=profile,
        title="Scenario A - controllo annuale",
        source="Seed hackathon",
    )


def _seed_scenario_b(db, profile: PatientProfile) -> None:
    medication = _create_medication(
        profile=profile,
        name="Spray nasale salino",
        dosage="2 puff",
        frequency="2/die",
        scheduled_time=time(9, 0),
        instructions="Uso sintomatico nei giorni con congestione.",
    )
    db.add_all(
        [
            MedicalCondition(
                patient_id=profile.id,
                name="Rinite ricorrente",
                notes="Peggiora quando dorme poco o lavora molte ore consecutive.",
            ),
            medication,
        ]
    )
    db.flush()

    entries = [
        (
            date.today() - timedelta(days=3),
            dict(
                sleep_hours=6.2,
                sleep_quality=5,
                energy_level=5,
                mood_level=6,
                stress_level=6,
                hydration_level=5,
                general_pain=2,
                general_notes="Settimana impegnativa, lieve tosse serale.",
            ),
            ("cough", 3, "torace"),
            ("temperature", "37.1", "C"),
            5120,
            360,
        ),
        (
            date.today() - timedelta(days=2),
            dict(
                sleep_hours=5.4,
                sleep_quality=4,
                energy_level=4,
                mood_level=5,
                stress_level=7,
                hydration_level=5,
                general_pain=3,
                general_notes="Sonno frammentato e più stanchezza nel pomeriggio.",
            ),
            ("cough", 4, "torace"),
            ("temperature", "37.3", "C"),
            4680,
            322,
        ),
        (
            date.today() - timedelta(days=1),
            dict(
                sleep_hours=4.9,
                sleep_quality=3,
                energy_level=3,
                mood_level=4,
                stress_level=8,
                hydration_level=4,
                general_pain=4,
                general_notes="Tosse più fastidiosa e riposo insufficiente.",
            ),
            ("cough", 5, "torace"),
            ("temperature", "37.6", "C"),
            4010,
            294,
        ),
        (
            date.today(),
            dict(
                sleep_hours=4.6,
                sleep_quality=3,
                energy_level=3,
                mood_level=4,
                stress_level=8,
                hydration_level=4,
                general_pain=4,
                general_notes="Ancora sonno scarso, tosse presente e poca energia.",
            ),
            ("cough", 6, "torace"),
            ("temperature", "37.8", "C"),
            3890,
            286,
        ),
    ]
    for day, entry_payload, symptom_payload, vital_payload, steps, sleep_minutes in entries:
        entry = _create_daily_entry(db, profile=profile, entry_date=day, **entry_payload)
        symptom_code, severity, body_location = symptom_payload
        db.add(
            SymptomEntry(
                daily_entry_id=entry.id,
                symptom_code=symptom_code,
                severity=severity,
                body_location=body_location,
            )
        )
        vital_type, value, unit = vital_payload
        db.add(
            VitalSignEntry(
                daily_entry_id=entry.id,
                type=vital_type,
                value=value,
                unit=unit,
                measured_at=_timestamp_for(day, 20, 30),
            )
        )
        db.add(
            MedicationLog(
                medication_id=medication.id,
                scheduled_at=_timestamp_for(day, 9, 0),
                taken_at=_timestamp_for(day, 9, 10),
                status=MedicationLogStatus.TAKEN,
                notes="Uso sintomatico registrato dal seed hackathon.",
            )
        )
        db.add(
            WearableDailySummary(
                patient_id=profile.id,
                summary_date=day,
                source_platform="android",
                source_name="Health Connect",
                steps_count=steps,
                sleep_minutes=sleep_minutes,
                heart_rate_avg_bpm=82,
                record_count=10,
                synced_at=_timestamp_for(day, 22, 15),
            )
        )

    db.add(
        Alert(
            patient_id=profile.id,
            severity=AlertSeverity.ATTENTION,
            alert_type="sleep_decline",
            title="Sonno ridotto negli ultimi giorni",
            description="Pattern di sonno scarso e sintomi in aumento da contestualizzare nel recap.",
            source_type="daily_entry",
            source_id=None,
            triggered_at=_timestamp_for(date.today(), 7, 30),
        )
    )
    _add_demo_document(
        db,
        profile=profile,
        title="Scenario B - referto visita recente",
        source="Seed hackathon",
    )


def _seed_scenario_c(db, profile: PatientProfile) -> None:
    medication = _create_medication(
        profile=profile,
        name="Antistaminico al bisogno",
        dosage="1 compressa",
        frequency="al bisogno",
        scheduled_time=time(21, 0),
        instructions="Uso occasionale per allergia stagionale.",
    )
    db.add_all(
        [
            Allergy(patient_id=profile.id, allergen="Graminacee", notes="Peggiora in primavera"),
            medication,
        ]
    )
    db.flush()

    entries = [
        (
            date.today() - timedelta(days=2),
            dict(
                sleep_hours=6.8,
                sleep_quality=6,
                energy_level=6,
                mood_level=6,
                stress_level=5,
                hydration_level=5,
                general_pain=1,
                general_notes="Trasferta regolare, preferenza per funzioni rapide offline.",
            ),
            None,
            ("heart_rate", "72", "bpm"),
        ),
        (
            date.today() - timedelta(days=1),
            dict(
                sleep_hours=5.9,
                sleep_quality=5,
                energy_level=5,
                mood_level=6,
                stress_level=6,
                hydration_level=5,
                general_pain=1,
                general_notes="Connettività intermittente durante il viaggio.",
            ),
            ("fatigue", 3, "generalizzato"),
            ("heart_rate", "76", "bpm"),
        ),
        (
            date.today(),
            dict(
                sleep_hours=6.1,
                sleep_quality=5,
                energy_level=5,
                mood_level=6,
                stress_level=5,
                hydration_level=5,
                general_pain=1,
                general_notes="Vuole un recap breve e privato perché oggi è spesso offline.",
            ),
            ("fatigue", 2, "generalizzato"),
            ("heart_rate", "74", "bpm"),
        ),
    ]
    for day, entry_payload, symptom_payload, vital_payload in entries:
        entry = _create_daily_entry(db, profile=profile, entry_date=day, **entry_payload)
        if symptom_payload is not None:
            symptom_code, severity, body_location = symptom_payload
            db.add(
                SymptomEntry(
                    daily_entry_id=entry.id,
                    symptom_code=symptom_code,
                    severity=severity,
                    body_location=body_location,
                )
            )
        vital_type, value, unit = vital_payload
        db.add(
            VitalSignEntry(
                daily_entry_id=entry.id,
                type=vital_type,
                value=value,
                unit=unit,
                measured_at=_timestamp_for(day, 18, 0),
            )
        )
    db.add(
        Alert(
            patient_id=profile.id,
            severity=AlertSeverity.INFO,
            alert_type="travel_mode",
            title="Profilo demo privacy-first",
            description="Scenario pensato per mostrare il recap privato locale anche con connettività ridotta.",
            source_type="patient_profile",
            source_id=profile.id,
            triggered_at=_timestamp_for(date.today(), 8, 0),
        )
    )


def _create_medication(
    *,
    profile: PatientProfile,
    name: str,
    dosage: str,
    frequency: str,
    scheduled_time: time,
    instructions: str,
) -> Medication:
    medication = Medication(
        patient_id=profile.id,
        name=name,
        dosage=dosage,
        frequency=frequency,
        active=True,
    )
    medication.schedules.append(
        MedicationSchedule(
            scheduled_time=scheduled_time,
            instructions=instructions,
            active=True,
        )
    )
    return medication


def _create_daily_entry(db, *, profile: PatientProfile, entry_date: date, **payload) -> DailyEntry:
    entry = DailyEntry(patient_id=profile.id, entry_date=entry_date, **payload)
    db.add(entry)
    db.flush()
    db.add(
        TimelineEvent(
            patient_id=profile.id,
            event_type=TimelineEventType.DAILY_ENTRY,
            source_type="daily_entry",
            source_id=entry.id,
            title=f"Check-up demo del {entry_date.isoformat()}",
            description="Voce del diario caricata dal seed hackathon.",
            event_date=_timestamp_for(entry_date, 21, 0),
        )
    )
    return entry


def _add_demo_document(db, *, profile: PatientProfile, title: str, source: str) -> None:
    try:
        storage = get_storage_service()
        image_bytes = base64.b64decode(_TINY_PNG_BASE64)
        stored = storage.save_bytes(
            object_key=f"patients/{profile.id}/documents/{title.lower().replace(' ', '-')}.png",
            data=image_bytes,
            content_type="image/png",
        )
        document = ClinicalDocument(
            patient_id=profile.id,
            title=title,
            document_type=ClinicalDocumentType.GENERIC_DOCUMENT,
            exam_date=date.today(),
            source=source,
            file_url=stored.object_key,
            original_filename=f"{title.lower().replace(' ', '-')}.png",
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
                title=f"{title} caricato",
                description="Documento seed pronto per demo e testing.",
                event_date=_timestamp_for(date.today(), 12, 0),
            )
        )
    except Exception:
        return


def _timestamp_for(target_date: date, hour: int, minute: int) -> object:
    return utcnow().replace(
        year=target_date.year,
        month=target_date.month,
        day=target_date.day,
        hour=hour,
        minute=minute,
        second=0,
        microsecond=0,
    )


if __name__ == "__main__":
    main()
