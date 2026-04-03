from datetime import date

from app.models.daily_entry import DailyEntry
from app.models.symptom_entry import SymptomEntry
from app.models.vital_sign_entry import VitalSignEntry
from app.rules.red_flags import RedFlagRuleEngine


def test_red_flag_engine_detects_chest_pain_and_low_saturation():
    entry = DailyEntry(
        patient_id="patient-1",
        entry_date=date(2026, 3, 20),
        general_pain=8,
    )
    entry.symptoms = [
        SymptomEntry(
            daily_entry_id="entry-1",
            symptom_code="chest_pain",
            severity=8,
            body_location="torace",
        )
    ]
    entry.vitals = [
        VitalSignEntry(
            daily_entry_id="entry-1",
            type="spo2",
            value="89",
            unit="%",
        )
    ]

    matches = RedFlagRuleEngine().evaluate(entry, [entry])
    codes = {match.rule_code for match in matches}

    assert "chest_pain" in codes
    assert "low_oxygen_saturation" in codes


def test_red_flag_engine_detects_persistent_high_fever_across_recent_entries():
    recent_entry = DailyEntry(
        patient_id="patient-1",
        entry_date=date(2026, 3, 20),
    )
    recent_entry.symptoms = []
    recent_entry.vitals = [
        VitalSignEntry(
            daily_entry_id="entry-1",
            type="temperature",
            value="39.1",
            unit="C",
        )
    ]

    previous_entry = DailyEntry(
        patient_id="patient-1",
        entry_date=date(2026, 3, 19),
    )
    previous_entry.symptoms = []
    previous_entry.vitals = [
        VitalSignEntry(
            daily_entry_id="entry-2",
            type="temperature",
            value="38.8",
            unit="C",
        )
    ]

    matches = RedFlagRuleEngine().evaluate(recent_entry, [recent_entry, previous_entry])
    codes = {match.rule_code for match in matches}

    assert "persistent_high_fever" in codes
