from datetime import date

from app.models.enums import ActivityLevel, AlcoholUse, BiologicalSex, ConditionStatus
from app.models.medical_condition import MedicalCondition
from app.models.family_history import FamilyHistoryEntry
from app.models.patient_profile import PatientProfile
from app.models.screening_program import ScreeningProgram
from app.models.screening_rule import ScreeningRule
from app.rules.screenings import ScreeningRuleEngine


def test_screening_rule_engine_supports_bmi_and_family_history() -> None:
    profile = PatientProfile(
        birth_date=date(1985, 4, 10),
        biological_sex=BiologicalSex.FEMALE,
        height_cm=165,
        weight_kg=82,
        smoker=False,
    )
    profile.family_history_entries = [
        FamilyHistoryEntry(relation="padre", condition_name="diabete tipo 2"),
    ]

    program = ScreeningProgram(
        code="prediabetes_diabetes_risk",
        name="Glicemia o HbA1c se rischio",
        description="Screening diabete",
        min_age=35,
        max_age=70,
        target_sex=None,
        interval_months=36,
        public_coverage_flag=False,
        category="cardiometabolico",
        recommendation_level="risk_based",
        cadence_label="Solo se rischio",
        explanation="Screening risk based",
        active=True,
    )
    program.rules = [
        ScreeningRule(
            rule_code="diabetes_bmi_risk",
            description="BMI elevato tra 35 e 70 anni.",
            min_age=35,
            max_age=70,
            min_bmi=25,
            active=True,
        ),
        ScreeningRule(
            rule_code="diabetes_family_history",
            description="Familiarita per diabete.",
            min_age=35,
            max_age=70,
            family_history_keyword="diabete",
            active=True,
        ),
    ]

    eligibility = ScreeningRuleEngine().evaluate(profile, program, reference_date=date(2026, 3, 24))

    assert eligibility.eligible is True
    assert eligibility.reason in {
        "BMI elevato tra 35 e 70 anni.",
        "Familiarita per diabete.",
    }


def test_screening_rule_engine_supports_condition_alcohol_and_activity_rules() -> None:
    profile = PatientProfile(
        birth_date=date(1988, 6, 4),
        biological_sex=BiologicalSex.MALE,
        smoker=False,
        alcohol_use=AlcoholUse.HIGH,
        activity_level=ActivityLevel.SEDENTARY,
    )
    profile.conditions = [
        MedicalCondition(
            name="Ipertensione arteriosa",
            status=ConditionStatus.ACTIVE,
        ),
    ]
    profile.family_history_entries = []

    program = ScreeningProgram(
        code="cardiometabolic_lifestyle_counseling",
        name="Counselling stile di vita",
        description="Counselling rischio cardiovascolare",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="stili_di_vita",
        recommendation_level="risk_based",
        cadence_label="Se rischio",
        explanation="Counselling stile di vita",
        active=True,
    )
    program.rules = [
        ScreeningRule(
            rule_code="alcohol_high",
            description="Consumo di alcol alto.",
            min_age=18,
            alcohol_use_required=AlcoholUse.HIGH,
            active=True,
        ),
        ScreeningRule(
            rule_code="low_activity",
            description="Attivita bassa.",
            min_age=18,
            activity_level_required=ActivityLevel.SEDENTARY,
            active=True,
        ),
        ScreeningRule(
            rule_code="hypertension",
            description="Ipertensione nota.",
            min_age=18,
            condition_keyword="ipert",
            active=True,
        ),
    ]

    eligibility = ScreeningRuleEngine().evaluate(profile, program, reference_date=date(2026, 4, 1))

    assert eligibility.eligible is True
    assert eligibility.reason in {
        "Consumo di alcol alto.",
        "Attivita bassa.",
        "Ipertensione nota.",
    }


def test_screening_rule_engine_supports_wave2_specialized_rules() -> None:
    female_profile = PatientProfile(
        birth_date=date(1948, 4, 10),
        biological_sex=BiologicalSex.FEMALE,
        smoker=False,
        former_smoker=True,
        smoking_pack_years=28,
        years_since_quitting=8,
        postmenopausal=True,
        fragility_fracture_history=True,
        falls_last_year=2,
        feels_unsteady=True,
        sexually_active=True,
        new_or_multiple_partners=True,
    )
    female_profile.conditions = []
    female_profile.family_history_entries = []

    osteoporosis_program = ScreeningProgram(
        code="osteoporosis_screening",
        name="Osteoporosi",
        description="Osteoporosi",
        min_age=50,
        max_age=None,
        target_sex=BiologicalSex.FEMALE,
        interval_months=24,
        public_coverage_flag=False,
        category="salute_ossea",
        recommendation_level="routine",
        cadence_label="Per eta o rischio",
        explanation="Osteoporosi",
        active=True,
    )
    osteoporosis_program.rules = []

    lung_program = ScreeningProgram(
        code="lung_cancer_screening",
        name="Polmone",
        description="Polmone",
        min_age=50,
        max_age=80,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="oncologia",
        recommendation_level="risk_based",
        cadence_label="Se rischio tabagico",
        explanation="Polmone",
        active=True,
    )
    lung_program.rules = []

    falls_program = ScreeningProgram(
        code="falls_prevention_review",
        name="Cadute",
        description="Cadute",
        min_age=65,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="funzionale",
        recommendation_level="risk_based",
        cadence_label="Se rischio",
        explanation="Cadute",
        active=True,
    )
    falls_program.rules = []

    sti_program = ScreeningProgram(
        code="sti_risk_assessment",
        name="MST",
        description="MST",
        min_age=15,
        max_age=None,
        target_sex=None,
        interval_months=None,
        public_coverage_flag=False,
        category="infezioni",
        recommendation_level="risk_based",
        cadence_label="Solo se rischio",
        explanation="MST",
        active=True,
    )
    sti_program.rules = []

    engine = ScreeningRuleEngine()
    assert engine.evaluate(
        female_profile,
        osteoporosis_program,
        reference_date=date(2026, 4, 1),
    ).eligible
    assert engine.evaluate(
        female_profile,
        lung_program,
        reference_date=date(2026, 4, 1),
    ).eligible
    assert engine.evaluate(
        female_profile,
        falls_program,
        reference_date=date(2026, 4, 1),
    ).eligible
    assert engine.evaluate(
        female_profile,
        sti_program,
        reference_date=date(2026, 4, 1),
    ).eligible

    male_profile = PatientProfile(
        birth_date=date(1956, 4, 10),
        biological_sex=BiologicalSex.MALE,
        smoker=False,
        former_smoker=True,
        smoking_pack_years=10,
    )
    male_profile.conditions = []
    male_profile.family_history_entries = []

    aaa_program = ScreeningProgram(
        code="abdominal_aortic_aneurysm_screening",
        name="AAA",
        description="AAA",
        min_age=65,
        max_age=75,
        target_sex=BiologicalSex.MALE,
        interval_months=1200,
        public_coverage_flag=False,
        category="vascolare",
        recommendation_level="risk_based",
        cadence_label="Una volta se rischio",
        explanation="AAA",
        active=True,
    )
    aaa_program.rules = []

    assert engine.evaluate(
        male_profile,
        aaa_program,
        reference_date=date(2026, 4, 1),
    ).eligible
