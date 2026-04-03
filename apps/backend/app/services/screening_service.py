from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import utcnow
from app.models.enums import ActivityLevel, AlcoholUse, BiologicalSex, ScreeningStatus, TimelineEventType
from app.models.screening_completion_record import ScreeningCompletionRecord
from app.models.patient_screening_status import PatientScreeningStatus
from app.models.regional_screening_availability import RegionalScreeningAvailability
from app.models.screening_program import ScreeningProgram
from app.models.screening_rule import ScreeningRule
from app.models.user import User
from app.repositories.screening_repository import ScreeningRepository
from app.repositories.timeline_repository import TimelineRepository
from app.rules.screenings import ScreeningRuleEngine
from app.services.profile_context import resolve_user_profile
from app.schemas.screenings import (
    PatientScreeningStatusResponse,
    RegionalAvailabilityResponse,
    ScreeningCatalogItemResponse,
)


@dataclass(slots=True)
class ScreeningSeedRule:
    rule_code: str
    description: str
    min_age: int | None = None
    max_age: int | None = None
    target_sex: BiologicalSex | None = None
    smoker_required: bool | None = None
    family_history_keyword: str | None = None
    condition_keyword: str | None = None
    alcohol_use_required: AlcoholUse | None = None
    activity_level_required: ActivityLevel | None = None
    min_bmi: float | None = None
    active: bool = True


@dataclass(slots=True)
class ScreeningSeedProgram:
    code: str
    name: str
    description: str
    min_age: int | None
    max_age: int | None
    target_sex: BiologicalSex | None
    interval_months: int | None
    public_coverage_flag: bool
    category: str
    recommendation_level: str
    cadence_label: str | None
    explanation: str
    booking_url: str | None
    rules: tuple[ScreeningSeedRule, ...]
    catalog_only: bool = False


ITALIAN_SCREENING_REGIONS = [
    ("IT", "Italia"),
    ("IT-ABR", "Abruzzo"),
    ("IT-BAS", "Basilicata"),
    ("IT-CAL", "Calabria"),
    ("IT-CAM", "Campania"),
    ("IT-EMR", "Emilia-Romagna"),
    ("IT-FVG", "Friuli Venezia Giulia"),
    ("IT-LAZ", "Lazio"),
    ("IT-LIG", "Liguria"),
    ("IT-LOM", "Lombardia"),
    ("IT-MAR", "Marche"),
    ("IT-MOL", "Molise"),
    ("IT-PIE", "Piemonte"),
    ("IT-PUG", "Puglia"),
    ("IT-SAR", "Sardegna"),
    ("IT-SIC", "Sicilia"),
    ("IT-TOS", "Toscana"),
    ("IT-TAA", "Trentino-Alto Adige/Südtirol"),
    ("IT-UMB", "Umbria"),
    ("IT-VDA", "Valle d'Aosta"),
    ("IT-VEN", "Veneto"),
]

VERIFIED_REGIONAL_SCREENING_PORTALS = {
    "IT-ABR": "https://sanita.regione.abruzzo.it/canale-prevenzione/SCREENING",
    "IT-BAS": "https://www.regione.basilicata.it/focus-su-prevenzione-e-screening-oncologico/",
    "IT-CAL": "https://www.regione.calabria.it/prevenzione-tumori-grande-partecipazione-alla-giornata-della-salute-organizzata-dalla-regione/",
    "IT-CAM": "https://www.regione.campania.it/it/printable/screening-in-campania",
    "IT-EMR": "https://salute.regione.emilia-romagna.it/screening/prevenzione-tumori",
    "IT-FVG": "https://www.regione.fvg.it/rafvg/cms/RAFVG/salute-sociale/screening-prevenzione-tumori/FOGLIA1/",
    "IT-LAZ": "https://www.salutelazio.it/screening-prenota-smart",
    "IT-LIG": "https://www.regione.liguria.it/homepage-salute/ultime-dal-canale/item/40562-settimana-nazionale-prevenzione-oncologica-marzo-2024.html",
    "IT-LOM": "https://prenotasalute.regione.lombardia.it/sito/Menu-principale/Come-prenotare",
    "IT-MAR": "https://www.regione.marche.it/Regione-Utile/Salute/Screening-oncologici",
    "IT-MOL": "https://www.regione.molise.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/15069",
    "IT-PIE": "https://www.regione.piemonte.it/web/temi/sanita/prevenzione/prevenzione-serena-programma-screening-oncologico-della-regione-piemonte",
    "IT-PUG": "https://www.regione.puglia.it/web/salute-sport-e-buona-vita/-/screening-oncologici-in-puglia-attivate-le-notifiche-su-app-io",
    "IT-SAR": "https://www.sardegnasalute.it/approfondimenti/screening/",
    "IT-SIC": "https://www.regione.sicilia.it/istituzioni/regione/strutture-regionali/assessorato-salute/dipartimento-attivita-sanitarie-osservatorio-epidemiologico/epidemiologia-prevenzione/piano/screening",
    "IT-TAA": "https://www.trentinosalute.net/layout/set/print/Argomenti/PREVENZIONE/Piano-provinciale-della-prevenzione-2021-2025/PL11-Screening-oncologici",
    "IT-TOS": "https://www.regione.toscana.it/-/screening-oncologici",
    "IT-UMB": "https://prevenzione.regione.umbria.it/argomento/screening-oncologici/",
    "IT-VDA": "https://www.regione.vda.it/sanita/prevenzione/programmi_screening/default_i.asp",
    "IT-VEN": "https://salute.regione.veneto.it/prevenzione-collettiva-e-sanit%C3%A0-pubblica/persona-e-salute/screening-oncologici",
}


DEFAULT_SCREENING_PROGRAMS = [
    ScreeningSeedProgram(
        code="preventive_annual_visit",
        name="Visita preventiva annuale",
        description="Controllo periodico con il medico per rivedere pressione, peso, salute mentale, vaccini e bisogni preventivi personali.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="prevenzione_generale",
        recommendation_level="routine",
        cadence_label="Annuale",
        explanation="Utile per fare il punto sulla prevenzione personale e decidere con il medico se servono esami o visite mirate.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="preventive_visit_adults",
                description="Una visita preventiva periodica aiuta a rivedere i bisogni di prevenzione in base a eta, profilo e fattori di rischio.",
                min_age=18,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="blood_pressure_adults",
        name="Controllo pressione arteriosa",
        description="Valutazione periodica della pressione arteriosa negli adulti.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="cardiometabolico",
        recommendation_level="routine",
        cadence_label="Periodico",
        explanation="Lo screening della pressione e raccomandato negli adulti; se elevata, va confermata con misurazioni ripetute o fuori dallo studio medico.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="blood_pressure_adults",
                description="Controllare periodicamente la pressione aiuta a intercettare precocemente valori elevati da confermare con nuove misurazioni.",
                min_age=18,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="weight_bmi_review",
        name="Peso, altezza e BMI",
        description="Rivalutazione periodica di peso, altezza e BMI in visita.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="cardiometabolico",
        recommendation_level="routine",
        cadence_label="Periodico",
        explanation="Peso, altezza e BMI aiutano a monitorare sovrappeso e obesita e a contestualizzare i controlli preventivi.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="weight_bmi_review_adults",
                description="Rivedere periodicamente peso, altezza e BMI aiuta a contestualizzare il rischio cardiometabolico.",
                min_age=18,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="mental_health_checkin",
        name="Screening salute mentale",
        description="Valutazione di base su umore, ansia, sonno e carico mentale.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="salute_mentale",
        recommendation_level="routine",
        cadence_label="Periodico",
        explanation="Uno screening della salute mentale in eta adulta puo aiutare a riconoscere precocemente segnali di depressione o sofferenza psicologica.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="mental_health_checkin_adults",
                description="Vale la pena rivedere periodicamente salute mentale, sonno e stress, soprattutto se l'equilibrio emotivo e cambiato.",
                min_age=18,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="tobacco_use_review",
        name="Revisione uso del tabacco",
        description="Aggiornamento periodico su fumo o altri prodotti del tabacco e sul bisogno di supporto per smettere.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="stili_di_vita",
        recommendation_level="routine",
        cadence_label="Annuale",
        explanation="Negli adulti vale la pena rivedere periodicamente se usi tabacco, se hai smesso o se serve un supporto per evitare ricadute.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="tobacco_use_review_adults",
                description="Rivedere periodicamente il consumo di tabacco aiuta a mantenere aggiornato il piano di prevenzione.",
                min_age=18,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="smoking_cessation_support",
        name="Supporto per smettere di fumare",
        description="Counselling e strumenti pratici da discutere se fumi attualmente.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="stili_di_vita",
        recommendation_level="risk_based",
        cadence_label="Se fumi",
        explanation="Se fumi, vale la pena discutere con il medico un supporto concreto per ridurre o interrompere il consumo di tabacco.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="smoking_cessation_support_current_smoker",
                description="Con fumo attivo e utile discutere supporto, counselling o strategie pratiche per smettere.",
                min_age=18,
                smoker_required=True,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="alcohol_use_review",
        name="Revisione consumo di alcol",
        description="Valutazione periodica del consumo di alcol per capire se servono aggiustamenti o supporto.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="stili_di_vita",
        recommendation_level="routine",
        cadence_label="Annuale",
        explanation="Negli adulti conviene rivedere periodicamente il consumo di alcol e se ci sono segnali che meritano attenzione.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="alcohol_use_review_adults",
                description="Rivedere periodicamente il consumo di alcol aiuta a intercettare pattern che meritano un confronto medico.",
                min_age=18,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="alcohol_risk_counseling",
        name="Counselling se consumo di alcol elevato",
        description="Se il consumo di alcol e alto, conviene discuterne con il medico e valutare un supporto breve e pratico.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="stili_di_vita",
        recommendation_level="risk_based",
        cadence_label="Se consumo alto",
        explanation="Un consumo elevato di alcol merita un confronto prudente e non giudicante per capire se servono strategie di riduzione o supporto.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="alcohol_risk_high_use",
                description="Se hai indicato un consumo di alcol alto, ha senso un counselling breve da discutere col medico.",
                min_age=18,
                alcohol_use_required=AlcoholUse.HIGH,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="hiv_once_lifetime",
        name="Test HIV almeno una volta",
        description="Screening HIV almeno una volta nella vita adulta, con ripetizione se persistono fattori di rischio.",
        min_age=15,
        max_age=65,
        target_sex=None,
        interval_months=1200,
        public_coverage_flag=False,
        category="infezioni",
        recommendation_level="routine",
        cadence_label="Almeno una volta",
        explanation="Lo screening HIV e raccomandato negli adolescenti e adulti 15-65 anni; puo essere ripetuto prima se il rischio continua.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="hiv_once_lifetime_age",
                description="Il test HIV e appropriato almeno una volta tra adolescenza e adulta giovane; si rivaluta se restano esposizioni a rischio.",
                min_age=15,
                max_age=65,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="hepatitis_c_once_lifetime",
        name="Test epatite C almeno una volta",
        description="Screening epatite C almeno una volta in eta adulta, con eventuale ripetizione se restano fattori di rischio.",
        min_age=18,
        max_age=79,
        target_sex=None,
        interval_months=1200,
        public_coverage_flag=False,
        category="infezioni",
        recommendation_level="routine",
        cadence_label="Almeno una volta",
        explanation="Lo screening per epatite C e raccomandato negli adulti 18-79 anni; spesso basta una volta se il rischio non persiste.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="hcv_once_lifetime_age",
                description="Il test per epatite C merita almeno una valutazione in eta adulta, con ripetizione solo se il rischio rimane presente.",
                min_age=18,
                max_age=79,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="lipid_profile_risk_based",
        name="Profilo lipidico se fattori di rischio",
        description="Colesterolo e assetto lipidico da valutare soprattutto se ci sono fattori di rischio cardiovascolare o familiarita importante.",
        min_age=20,
        max_age=39,
        target_sex=None,
        interval_months=36,
        public_coverage_flag=False,
        category="cardiometabolico",
        recommendation_level="risk_based",
        cadence_label="Solo se rischio",
        explanation="In giovane eta il profilo lipidico si anticipa soprattutto con fumo, forte familiarita cardiovascolare o sospetto di ipercolesterolemia familiare.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="lipids_smoker",
                description="Il profilo lipidico merita una valutazione anticipata se sei fumatore.",
                min_age=20,
                max_age=39,
                smoker_required=True,
            ),
            ScreeningSeedRule(
                rule_code="lipids_family_history_infarction",
                description="Il profilo lipidico e da considerare se in famiglia ci sono eventi cardiovascolari precoci o forte sospetto di ipercolesterolemia.",
                min_age=20,
                max_age=39,
                family_history_keyword="infarto",
            ),
            ScreeningSeedRule(
                rule_code="lipids_family_history_cholesterol",
                description="Il profilo lipidico e da considerare se in famiglia c'e familiarita per colesterolo molto alto o malattia cardiovascolare precoce.",
                min_age=20,
                max_age=39,
                family_history_keyword="colester",
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="prediabetes_diabetes_risk",
        name="Glicemia o HbA1c se rischio",
        description="Screening per prediabete e diabete soprattutto in eta 35-70 anni con sovrappeso/obesita o familiarita rilevante.",
        min_age=35,
        max_age=70,
        target_sex=None,
        interval_months=36,
        public_coverage_flag=False,
        category="cardiometabolico",
        recommendation_level="risk_based",
        cadence_label="Solo se rischio",
        explanation="Lo screening diabete si concentra soprattutto tra 35 e 70 anni con sovrappeso o obesita; puo anticiparsi se il rischio e piu alto.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="diabetes_bmi_risk",
                description="Con BMI elevato tra 35 e 70 anni ha senso valutare glicemia o HbA1c con il medico.",
                min_age=35,
                max_age=70,
                min_bmi=25,
            ),
            ScreeningSeedRule(
                rule_code="diabetes_family_history",
                description="Con familiarita per diabete vale la pena parlare con il medico di uno screening anticipato o piu attento.",
                min_age=35,
                max_age=70,
                family_history_keyword="diabete",
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="obesity_behavioral_support",
        name="Supporto comportamentale per obesita",
        description="Percorso da discutere se il BMI rientra nel range di obesita, per definire obiettivi realistici su alimentazione, attivita e follow-up.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="stili_di_vita",
        recommendation_level="risk_based",
        cadence_label="Se BMI elevato",
        explanation="Quando il BMI rientra nel range di obesita, vale la pena discutere interventi comportamentali strutturati e sostenibili.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="obesity_behavioral_support_bmi_30",
                description="Con BMI nel range di obesita conviene discutere un supporto comportamentale strutturato.",
                min_age=18,
                min_bmi=30,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="cardiometabolic_lifestyle_counseling",
        name="Counselling su alimentazione e movimento se rischio cardiovascolare",
        description="Con fattori di rischio cardiometabolico vale la pena discutere obiettivi pratici su alimentazione, movimento e routine.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="stili_di_vita",
        recommendation_level="risk_based",
        cadence_label="Se rischio",
        explanation="Fumo, eccesso di peso, poca attivita o condizioni cardiometaboliche note rendono utile un counselling pratico sullo stile di vita.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_smoker",
                description="Con fumo attivo e utile rivedere alimentazione, movimento e obiettivi realistici di prevenzione cardiovascolare.",
                min_age=18,
                smoker_required=True,
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_overweight",
                description="Con BMI elevato vale la pena parlare di alimentazione e movimento in ottica cardiometabolica.",
                min_age=18,
                min_bmi=25,
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_sedentary",
                description="Se hai indicato un livello di attivita basso, puo essere utile concordare obiettivi graduali di movimento.",
                min_age=18,
                activity_level_required=ActivityLevel.SEDENTARY,
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_light_activity",
                description="Se il movimento abituale e limitato, puo essere utile definire con il medico piccoli passi pratici per aumentarlo.",
                min_age=18,
                activity_level_required=ActivityLevel.LIGHT,
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_diabetes",
                description="Con diabete o prediabete noto vale la pena discutere un counselling pratico su alimentazione e movimento.",
                min_age=18,
                condition_keyword="diabet",
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_hypertension",
                description="Con pressione alta o ipertensione nota puo essere utile un counselling mirato su stile di vita e monitoraggio.",
                min_age=18,
                condition_keyword="ipert",
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_dyslipidemia",
                description="Con dislipidemia o colesterolo alto noto vale la pena rivedere lo stile di vita in ottica preventiva.",
                min_age=18,
                condition_keyword="colester",
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_dyslipidemia_keyword",
                description="Con dislipidemia nota vale la pena rivedere stile di vita e obiettivi cardiometabolici.",
                min_age=18,
                condition_keyword="dislip",
            ),
            ScreeningSeedRule(
                rule_code="lifestyle_cvd_family_history",
                description="Con familiarita cardiovascolare precoce e utile discutere alimentazione, movimento e fattori modificabili.",
                min_age=18,
                family_history_keyword="infarto",
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="vaccination_review",
        name="Revisione vaccini",
        description="Controllo periodico dello stato vaccinale e dei richiami.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="vaccini",
        recommendation_level="routine",
        cadence_label="Annuale",
        explanation="Rivedere periodicamente i vaccini aiuta a mantenere aggiornati richiami, influenza, COVID e recuperi come HPV se pertinenti.",
        booking_url=None,
        rules=(
            ScreeningSeedRule(
                rule_code="vaccination_review_adults",
                description="Una revisione annuale dei vaccini aiuta a capire se mancano richiami o recuperi indicati per eta e situazione personale.",
                min_age=18,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="sti_risk_assessment",
        name="Test MST solo se rischio",
        description="Clamidia, gonorrea, sifilide o altre MST si valutano in base a esposizioni, partner e sintomi, non automaticamente in tutti gli asintomatici.",
        min_age=15,
        max_age=None,
        target_sex=None,
        interval_months=None,
        public_coverage_flag=False,
        category="infezioni",
        recommendation_level="risk_based",
        cadence_label="Solo se rischio",
        explanation="I test per infezioni sessualmente trasmesse vanno personalizzati in base a comportamento sessuale, esposizioni e sintomi dichiarati nel profilo.",
        booking_url=None,
        rules=(),
        catalog_only=False,
    ),
    ScreeningSeedProgram(
        code="preconception_review",
        name="Percorso preconcezionale",
        description="Revisione di farmaci, vaccini, folati e condizioni cliniche se stai cercando una gravidanza.",
        min_age=18,
        max_age=45,
        target_sex=BiologicalSex.FEMALE,
        interval_months=12,
        public_coverage_flag=False,
        category="gravidanza_preconcepimento",
        recommendation_level="risk_based",
        cadence_label="Se stai cercando una gravidanza",
        explanation="Se stai cercando una gravidanza, conviene rivedere in anticipo farmaci, vaccini, integrazione di folati e condizioni note.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="pregnancy_review",
        name="Revisione prevenzione in gravidanza",
        description="Promemoria prudente per rivedere vaccini, farmaci e bisogni preventivi se la gravidanza e gia in corso.",
        min_age=18,
        max_age=50,
        target_sex=BiologicalSex.FEMALE,
        interval_months=6,
        public_coverage_flag=False,
        category="gravidanza_preconcepimento",
        recommendation_level="risk_based",
        cadence_label="Se gravidanza in corso",
        explanation="Se la gravidanza e gia in corso, conviene rivedere farmaci, vaccini e follow-up con il medico o l'ostetrica.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="osteoporosis_screening",
        name="Valutazione osteoporosi / densitometria",
        description="Valutazione della salute ossea e, quando indicato, discussione di una densitometria o screening per osteoporosi.",
        min_age=50,
        max_age=None,
        target_sex=BiologicalSex.FEMALE,
        interval_months=24,
        public_coverage_flag=False,
        category="salute_ossea",
        recommendation_level="routine",
        cadence_label="Per eta o rischio",
        explanation="Nelle donne dai 65 anni in su, o prima se post-menopausa con rischio osseo, vale la pena discutere lo screening per osteoporosi.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="lung_cancer_screening",
        name="Screening polmone se storia tabagica rilevante",
        description="Valutazione da discutere se eta e storia tabagica rientrano nei criteri tipici dello screening del polmone.",
        min_age=50,
        max_age=80,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="oncologia",
        recommendation_level="risk_based",
        cadence_label="Se rischio tabagico",
        explanation="Questa regola richiede eta, pack-years e stato attuale o pregresso del fumo.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="abdominal_aortic_aneurysm_screening",
        name="Ecografia aorta addominale se storia tabagica",
        description="Ecografia dell'aorta addominale da discutere in alcuni profili maschili con storia di fumo.",
        min_age=65,
        max_age=75,
        target_sex=BiologicalSex.MALE,
        interval_months=1200,
        public_coverage_flag=False,
        category="vascolare",
        recommendation_level="risk_based",
        cadence_label="Una volta se rischio",
        explanation="Nei profili maschili tra 65 e 75 anni con storia di fumo puo essere utile discutere una singola ecografia dell'aorta addominale.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="falls_prevention_review",
        name="Revisione rischio cadute",
        description="Valutazione di equilibrio, forza, instabilita e sicurezza domestica se ci sono cadute o timore di cadere.",
        min_age=65,
        max_age=None,
        target_sex=None,
        interval_months=12,
        public_coverage_flag=False,
        category="funzionale",
        recommendation_level="risk_based",
        cadence_label="Se rischio",
        explanation="Se negli ultimi 12 mesi ci sono state cadute o instabilita, conviene parlarne con il medico e organizzare la prevenzione.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="prostate_psa_shared_decision",
        name="PSA / prevenzione prostata",
        description="Tra 55 e 69 anni il PSA va discusso caso per caso e non proposto automaticamente a tutti.",
        min_age=55,
        max_age=69,
        target_sex=BiologicalSex.MALE,
        interval_months=24,
        public_coverage_flag=False,
        category="urologia",
        recommendation_level="shared_decision",
        cadence_label="Decisione condivisa",
        explanation="Per il PSA la decisione deve essere condivisa con il medico, bilanciando benefici, limiti e possibili falsi positivi.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="skin_cancer_shared_decision",
        name="Controllo cute / rischio melanoma",
        description="Nella popolazione generale asintomatica non c'e uno screening automatico forte; con rischio personale ha senso discuterne.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=24,
        public_coverage_flag=False,
        category="dermatologia",
        recommendation_level="shared_decision",
        cadence_label="Decisione condivisa",
        explanation="ClinDiary non propone screening cutanei automatici di massa, ma puo segnalare quando esistono fattori che meritano discussione.",
        booking_url=None,
        rules=(),
        catalog_only=False,
    ),
    ScreeningSeedProgram(
        code="vision_screening_shared_decision",
        name="Controllo visivo nell'anziano asintomatico",
        description="Negli adulti piu anziani senza sintomi il controllo visivo periodico non va automatizzato in modo forte.",
        min_age=65,
        max_age=None,
        target_sex=None,
        interval_months=24,
        public_coverage_flag=False,
        category="oculistica",
        recommendation_level="shared_decision",
        cadence_label="Decisione condivisa",
        explanation="Se ci sono difficolta visive o dubbi pratici, il controllo visivo va personalizzato insieme al medico o all'oculista.",
        booking_url=None,
        rules=(),
    ),
    ScreeningSeedProgram(
        code="vitamin_d_general_screening",
        name="Vitamina D per tutti gli asintomatici",
        description="ClinDiary non propone in automatico il dosaggio della vitamina D come routine per tutti gli asintomatici.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=None,
        public_coverage_flag=False,
        category="laboratorio",
        recommendation_level="not_routine",
        cadence_label="Non di routine",
        explanation="Il dosaggio della vitamina D va contestualizzato e non va trasformato in automatismo di massa negli asintomatici.",
        booking_url=None,
        rules=(),
        catalog_only=True,
    ),
    ScreeningSeedProgram(
        code="thyroid_general_screening",
        name="Screening tiroide per tutti gli asintomatici",
        description="ClinDiary non propone automaticamente TSH o pannelli tiroidei come routine negli asintomatici senza contesto.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=None,
        public_coverage_flag=False,
        category="laboratorio",
        recommendation_level="not_routine",
        cadence_label="Non di routine",
        explanation="I test tiroidei vanno contestualizzati in base a sintomi, storia clinica e giudizio medico.",
        booking_url=None,
        rules=(),
        catalog_only=True,
    ),
    ScreeningSeedProgram(
        code="annual_lab_panels_general",
        name="Pannelli ematici annuali per tutti",
        description="Analisi complete annuali di routine per tutti gli asintomatici non vengono suggerite automaticamente da ClinDiary.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=None,
        public_coverage_flag=False,
        category="laboratorio",
        recommendation_level="not_routine",
        cadence_label="Non di routine",
        explanation="I pannelli ematici generalisti vanno decisi in base a sintomi, rischio e contesto clinico, non come automatismo universale.",
        booking_url=None,
        rules=(),
        catalog_only=True,
    ),
    ScreeningSeedProgram(
        code="testicular_cancer_routine_screening",
        name="Screening routinario tumore del testicolo",
        description="Negli uomini asintomatici non e raccomandato uno screening routinario programmato del tumore del testicolo.",
        min_age=15,
        max_age=39,
        target_sex=BiologicalSex.MALE,
        interval_months=None,
        public_coverage_flag=False,
        category="oncologia",
        recommendation_level="not_routine",
        cadence_label="Non di routine",
        explanation="In assenza di sintomi o fattori specifici non e raccomandato programmare screening routinari o ecografie testicolari preventive per tutti.",
        booking_url=None,
        rules=(),
        catalog_only=True,
    ),
    ScreeningSeedProgram(
        code="generic_ultrasound_asymptomatic",
        name="Ecografie generiche senza sintomi",
        description="Ecografie addominali o di altri distretti senza sintomi o rischio specifico non sono di routine nella popolazione asintomatica.",
        min_age=18,
        max_age=None,
        target_sex=None,
        interval_months=None,
        public_coverage_flag=False,
        category="imaging",
        recommendation_level="not_routine",
        cadence_label="Non di routine",
        explanation="In assenza di sintomi o fattori di rischio specifici non e prudente proporre ecografie generiche di screening come routine annuale.",
        booking_url=None,
        rules=(),
        catalog_only=True,
    ),
    ScreeningSeedProgram(
        code="cervical_cancer_it",
        name="Screening cervice uterina",
        description="Screening periodico per la prevenzione del tumore del collo dell'utero.",
        min_age=25,
        max_age=64,
        target_sex=BiologicalSex.FEMALE,
        interval_months=36,
        public_coverage_flag=True,
        category="oncologia",
        recommendation_level="routine",
        cadence_label="Programma pubblico",
        explanation="Consigliato per profili femminili adulti nel range eta previsto dai programmi pubblici italiani.",
        booking_url="https://www.salute.gov.it/",
        rules=(
            ScreeningSeedRule(
                rule_code="cervical_age_female",
                description="Consigliato per profili femminili adulti nel range eta previsto dai programmi pubblici italiani.",
                min_age=25,
                max_age=64,
                target_sex=BiologicalSex.FEMALE,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="mammography_it",
        name="Mammografia preventiva",
        description="Screening mammografico periodico per prevenzione oncologica.",
        min_age=50,
        max_age=69,
        target_sex=BiologicalSex.FEMALE,
        interval_months=24,
        public_coverage_flag=True,
        category="oncologia",
        recommendation_level="routine",
        cadence_label="Programma pubblico",
        explanation="Consigliato secondo i criteri di fascia eta e sesso biologico del programma di prevenzione.",
        booking_url="https://www.salute.gov.it/",
        rules=(
            ScreeningSeedRule(
                rule_code="mammography_age_female",
                description="Consigliato secondo i criteri di fascia eta e sesso biologico del programma di prevenzione.",
                min_age=50,
                max_age=69,
                target_sex=BiologicalSex.FEMALE,
            ),
        ),
    ),
    ScreeningSeedProgram(
        code="colorectal_it",
        name="Screening colon-retto",
        description="Prevenzione oncologica con test periodici per colon-retto.",
        min_age=50,
        max_age=74,
        target_sex=None,
        interval_months=24,
        public_coverage_flag=True,
        category="oncologia",
        recommendation_level="routine",
        cadence_label="Programma pubblico",
        explanation="Consigliato in base all'eta per programmi pubblici di screening del colon-retto.",
        booking_url="https://www.salute.gov.it/",
        rules=(
            ScreeningSeedRule(
                rule_code="colorectal_age_all",
                description="Consigliato in base all'eta per programmi pubblici di screening del colon-retto.",
                min_age=50,
                max_age=74,
            ),
        ),
    ),
]


class ScreeningService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.repository = ScreeningRepository(db)
        self.timeline_repository = TimelineRepository(db)
        self.rule_engine = ScreeningRuleEngine()

    def list_catalog(
        self,
        user: User,
        *,
        region_code: str | None = None,
    ) -> list[ScreeningCatalogItemResponse]:
        profile = self._require_profile(user)
        self.ensure_catalog_seeded()
        resolved_region_code = self._region_code_string(region_code or profile.region_code) or "IT"
        return [
            ScreeningCatalogItemResponse(
                id=program.id,
                code=program.code,
                name=program.name,
                description=program.description,
                min_age=program.min_age,
                max_age=program.max_age,
                target_sex=program.target_sex,
                interval_months=program.interval_months,
                public_coverage_flag=program.public_coverage_flag,
                category=program.category,
                care_pathway=self._care_pathway_for_program(program),
                recommendation_level=program.recommendation_level,
                cadence_label=program.cadence_label,
                catalog_only=program.catalog_only,
                explanation=program.explanation,
                active=program.active,
                regional_availability=self._availability_responses(
                    program.regional_availability,
                    resolved_region_code,
                ),
            )
            for program in self.repository.list_programs()
            if program.active
        ]

    def list_patient_screenings(
        self,
        user: User,
        *,
        region_code: str | None = None,
        emit_notifications: bool = True,
    ) -> list[PatientScreeningStatusResponse]:
        profile = self._require_profile(user)
        resolved_region_code = self._region_code_string(region_code or profile.region_code) or "IT"
        statuses = self._recompute_for_profile(profile.id, emit_notifications=emit_notifications)
        completion_map = self._current_year_completion_map(profile.id)
        return [
            self._to_status_response(
                item,
                region_code=resolved_region_code,
                current_year_completion_map=completion_map,
            )
            for item in statuses
        ]

    def recompute_patient_screenings(
        self,
        user: User,
        *,
        region_code: str | None = None,
    ) -> list[PatientScreeningStatusResponse]:
        return self.list_patient_screenings(user, region_code=region_code, emit_notifications=True)

    def mark_done(
        self,
        user: User,
        status_id: UUID,
        *,
        done_date: date,
        region_code: str | None = None,
    ) -> PatientScreeningStatusResponse:
        profile = self._require_profile(user)
        self.ensure_catalog_seeded()
        resolved_region_code = self._region_code_string(region_code or profile.region_code) or "IT"
        status_item = self.repository.get_status_for_patient(profile.id, status_id)
        if status_item is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Screening status not found")

        existing_record = self.repository.get_completion_record_for_date(
            profile.id,
            status_item.screening_program_id,
            done_date,
        )
        if existing_record is None:
            self.repository.add_completion_record(
                ScreeningCompletionRecord(
                    patient_id=profile.id,
                    screening_program_id=status_item.screening_program_id,
                    completed_on=done_date,
                )
            )
        self.db.flush()
        self._refresh_status_from_completion_history(profile.id, status_item)
        self._sync_timeline(status_item)
        self.db.flush()

        from app.services.notification_service import NotificationService

        NotificationService(self.db).sync_screening_notifications_for_patient(profile.id)
        self.db.commit()
        self.db.refresh(status_item)
        return self._to_status_response(
            status_item,
            region_code=resolved_region_code,
            current_year_completion_map=self._current_year_completion_map(profile.id),
        )

    def clear_current_year_completion(
        self,
        user: User,
        status_id: UUID,
        *,
        region_code: str | None = None,
    ) -> PatientScreeningStatusResponse:
        profile = self._require_profile(user)
        self.ensure_catalog_seeded()
        resolved_region_code = self._region_code_string(region_code or profile.region_code) or "IT"
        status_item = self.repository.get_status_for_patient(profile.id, status_id)
        if status_item is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Screening status not found")

        year_start, year_end = self._current_year_range()
        self.repository.delete_completion_records_in_range(
            profile.id,
            status_item.screening_program_id,
            start_date=year_start,
            end_date=year_end,
        )
        self._refresh_status_from_completion_history(profile.id, status_item)
        self._sync_timeline(status_item)
        self.db.flush()

        from app.services.notification_service import NotificationService

        NotificationService(self.db).sync_screening_notifications_for_patient(profile.id)
        self.db.commit()
        self.db.refresh(status_item)
        return self._to_status_response(
            status_item,
            region_code=resolved_region_code,
            current_year_completion_map=self._current_year_completion_map(profile.id),
        )

    def ensure_catalog_seeded(self) -> None:
        existing = {program.code: program for program in self.repository.list_programs()}
        for item in DEFAULT_SCREENING_PROGRAMS:
            program = existing.get(item.code)
            if program is None:
                program = ScreeningProgram(
                    code=item.code,
                    name=item.name,
                    description=item.description,
                    min_age=item.min_age,
                    max_age=item.max_age,
                    target_sex=item.target_sex,
                    interval_months=item.interval_months,
                    public_coverage_flag=item.public_coverage_flag,
                    category=item.category,
                    recommendation_level=item.recommendation_level,
                    cadence_label=item.cadence_label,
                    catalog_only=item.catalog_only,
                    explanation=item.explanation,
                    active=True,
                )
                self.repository.add_program(program)
                self.db.flush()
            self._apply_seed_program(program, item)
        self.db.commit()

    def _recompute_for_profile(
        self,
        patient_id: UUID,
        *,
        emit_notifications: bool,
    ) -> list[PatientScreeningStatus]:
        self.ensure_catalog_seeded()
        profile = self._require_profile_by_id(patient_id)

        programs = [
            program
            for program in self.repository.list_programs()
            if program.active and not program.catalog_only
        ]
        existing_map = {
            item.screening_program_id: item for item in self.repository.list_statuses_for_patient(patient_id)
        }
        tracked_ids: set[UUID] = set()

        for program in programs:
            eligibility = self.rule_engine.evaluate(profile, program)
            status_item = existing_map.get(program.id)
            latest_completion = self.repository.get_latest_completion_date(patient_id, program.id)
            if not eligibility.eligible:
                if status_item is not None:
                    status_item.last_done_date = latest_completion
                if status_item is not None and status_item.last_done_date is not None:
                    status_item.recommendation_reason = eligibility.reason
                    tracked_ids.add(status_item.id)
                continue

            if status_item is None:
                status_item = PatientScreeningStatus(
                    patient_id=patient_id,
                    screening_program_id=program.id,
                )
                self.repository.add_status(status_item)
                self.db.flush()
            status_item.last_done_date = latest_completion

            self._apply_status_logic(status_item, program, eligibility.reason)
            self._sync_timeline(status_item)
            tracked_ids.add(status_item.id)

        if emit_notifications:
            from app.services.notification_service import NotificationService

            NotificationService(self.db).sync_screening_notifications_for_patient(patient_id)
        self.db.commit()

        statuses = self.repository.list_statuses_for_patient(patient_id)
        return [item for item in statuses if item.id in tracked_ids or item.last_done_date is not None]

    def _apply_status_logic(
        self,
        status_item: PatientScreeningStatus,
        program: ScreeningProgram,
        reason: str,
    ) -> None:
        today = date.today()
        interval_months = program.interval_months or 12

        if status_item.last_done_date is None:
            status_item.status = ScreeningStatus.RECOMMENDED
            status_item.next_due_date = today
            status_item.recommendation_reason = reason
            return

        next_due = self._add_months(status_item.last_done_date, interval_months)
        status_item.next_due_date = next_due
        if status_item.status == ScreeningStatus.SCHEDULED and next_due > today:
            status_item.recommendation_reason = reason
            return
        if next_due < today:
            status_item.status = ScreeningStatus.OVERDUE
            status_item.recommendation_reason = (
                f"{reason} Ultimo screening registrato il {status_item.last_done_date.isoformat()}, "
                f"ora oltre l'intervallo di {interval_months} mesi."
            )
            return
        status_item.status = ScreeningStatus.COMPLETED
        status_item.recommendation_reason = (
            f"{reason} Screening aggiornato entro l'intervallo raccomandato di {interval_months} mesi."
        )

    def _refresh_status_from_completion_history(
        self,
        patient_id: UUID,
        status_item: PatientScreeningStatus,
    ) -> None:
        latest_completion = self.repository.get_latest_completion_date(
            patient_id,
            status_item.screening_program_id,
        )
        status_item.last_done_date = latest_completion
        eligibility = self.rule_engine.evaluate(status_item.patient, status_item.screening_program)
        if not eligibility.eligible and latest_completion is None:
            status_item.status = ScreeningStatus.NEVER_DONE
            status_item.next_due_date = None
            status_item.recommendation_reason = eligibility.reason
            return
        self._apply_status_logic(
            status_item,
            status_item.screening_program,
            eligibility.reason if eligibility.eligible else status_item.screening_program.explanation or status_item.screening_program.description,
        )

    def _sync_timeline(self, status_item: PatientScreeningStatus) -> None:
        program = status_item.screening_program
        if status_item.status == ScreeningStatus.COMPLETED:
            title = f"Screening completato: {program.name}"
            description = (
                f"Ultimo completamento registrato il {status_item.last_done_date.isoformat()}. "
                f"Prossima scadenza prevista il {(status_item.next_due_date or status_item.last_done_date).isoformat()}."
            )
            event_type = TimelineEventType.SCREENING_COMPLETED
            event_date = datetime.combine(
                status_item.last_done_date,
                time(hour=12),
                tzinfo=utcnow().tzinfo,
            )
        else:
            due_label = "in ritardo" if status_item.status == ScreeningStatus.OVERDUE else "consigliato"
            title = f"Screening {due_label}: {program.name}"
            description = status_item.recommendation_reason or program.description
            event_type = TimelineEventType.SCREENING_DUE
            event_date = datetime.combine(
                status_item.next_due_date or date.today(),
                time(hour=9),
                tzinfo=utcnow().tzinfo,
            )
        self.timeline_repository.upsert_source_event(
            patient_id=status_item.patient_id,
            source_type="screening_status",
            source_id=status_item.id,
            event_type=event_type,
            title=title,
            description=description,
            event_date=event_date,
        )

    def _to_status_response(
        self,
        item: PatientScreeningStatus,
        *,
        region_code: str | None = None,
        current_year_completion_map: dict[UUID, date] | None = None,
    ) -> PatientScreeningStatusResponse:
        current_year_completion_map = (
            current_year_completion_map
            if current_year_completion_map is not None
            else self._current_year_completion_map(item.patient_id)
        )
        current_year_completed_on = current_year_completion_map.get(item.screening_program_id)
        return PatientScreeningStatusResponse(
            id=item.id,
            screening_program_id=item.screening_program.id,
            screening_code=item.screening_program.code,
            screening_name=item.screening_program.name,
            screening_category=item.screening_program.category,
            care_pathway=self._care_pathway_for_program(item.screening_program),
            recommendation_level=item.screening_program.recommendation_level,
            cadence_label=item.screening_program.cadence_label,
            public_coverage_flag=item.screening_program.public_coverage_flag,
            explanation=item.screening_program.explanation,
            recommendation_reason=item.recommendation_reason,
            last_done_date=item.last_done_date,
            next_due_date=item.next_due_date,
            completed_this_year=current_year_completed_on is not None,
            current_year_last_completed_on=current_year_completed_on,
            status=item.status,
            regional_availability=self._availability_responses(
                item.screening_program.regional_availability,
                region_code,
            ),
        )

    @staticmethod
    def _availability_responses(
        availability_items,
        region_code: str | None,
    ) -> list[RegionalAvailabilityResponse]:
        normalized_code = region_code.strip().upper() if region_code else None
        filtered = [
            item
            for item in availability_items
            if item.active and (normalized_code is None or item.region_code.upper() == normalized_code)
        ]
        if not filtered:
            filtered = [item for item in availability_items if item.active and item.region_code.upper() == "IT"]
        return [RegionalAvailabilityResponse.model_validate(item) for item in filtered]

    def _apply_seed_program(
        self,
        program: ScreeningProgram,
        item: ScreeningSeedProgram,
    ) -> None:
        program.name = item.name
        program.description = item.description
        program.min_age = item.min_age
        program.max_age = item.max_age
        program.target_sex = item.target_sex
        program.interval_months = item.interval_months
        program.public_coverage_flag = item.public_coverage_flag
        program.category = item.category
        program.recommendation_level = item.recommendation_level
        program.cadence_label = item.cadence_label
        program.catalog_only = item.catalog_only
        program.explanation = item.explanation
        program.active = True
        self._sync_program_rules(program, item.rules)
        self._sync_program_availability(
            program,
            booking_url=item.booking_url,
            public_program=item.public_coverage_flag,
        )

    def _sync_program_rules(
        self,
        program: ScreeningProgram,
        rules: tuple[ScreeningSeedRule, ...],
    ) -> None:
        existing_signature = sorted(
            (
                rule.rule_code,
                rule.description,
                rule.min_age,
                rule.max_age,
                rule.target_sex,
                rule.smoker_required,
                rule.family_history_keyword,
                rule.condition_keyword,
                rule.alcohol_use_required,
                rule.activity_level_required,
                rule.min_bmi,
                rule.active,
            )
            for rule in program.rules
        )
        target_signature = sorted(
            (
                rule.rule_code,
                rule.description,
                rule.min_age,
                rule.max_age,
                rule.target_sex,
                rule.smoker_required,
                rule.family_history_keyword,
                rule.condition_keyword,
                rule.alcohol_use_required,
                rule.activity_level_required,
                rule.min_bmi,
                rule.active,
            )
            for rule in rules
        )
        if existing_signature == target_signature:
            return

        for existing_rule in list(program.rules):
            self.db.delete(existing_rule)
        self.db.flush()

        for rule in rules:
            self.repository.add_rule(
                ScreeningRule(
                    screening_program_id=program.id,
                    rule_code=rule.rule_code,
                    description=rule.description,
                    min_age=rule.min_age,
                    max_age=rule.max_age,
                    target_sex=rule.target_sex,
                    smoker_required=rule.smoker_required,
                    family_history_keyword=rule.family_history_keyword,
                    condition_keyword=rule.condition_keyword,
                    alcohol_use_required=rule.alcohol_use_required,
                    activity_level_required=rule.activity_level_required,
                    min_bmi=rule.min_bmi,
                    active=rule.active,
                )
            )
        self.db.flush()

    def _sync_program_availability(
        self,
        program: ScreeningProgram,
        *,
        booking_url: str | None,
        public_program: bool,
    ) -> None:
        target_items = [
            (
                region_code,
                region_name,
                self._booking_url_for_region(region_code, booking_url, public_program),
                self._availability_notes_for_region(region_code, region_name, public_program),
                True,
            )
            for region_code, region_name in ITALIAN_SCREENING_REGIONS
        ]
        existing_signature = sorted(
            (
                availability.region_code,
                availability.region_name,
                availability.booking_url,
                availability.notes,
                availability.active,
            )
            for availability in program.regional_availability
        )
        if existing_signature == sorted(target_items):
            return

        for availability in list(program.regional_availability):
            self.db.delete(availability)
        self.db.flush()

        for region_code, region_name, item_booking_url, notes, active in target_items:
            self.repository.add_availability(
                RegionalScreeningAvailability(
                    screening_program_id=program.id,
                    region_code=region_code,
                    region_name=region_name,
                    booking_url=item_booking_url,
                    notes=notes,
                    active=active,
                )
            )
        self.db.flush()

    @staticmethod
    def _booking_url_for_region(
        region_code: str,
        fallback_booking_url: str | None,
        public_program: bool,
    ) -> str | None:
        if not public_program:
            return None
        portal = VERIFIED_REGIONAL_SCREENING_PORTALS.get(region_code.upper())
        if portal is not None:
            return portal
        return fallback_booking_url

    @staticmethod
    def _availability_notes_for_region(
        region_code: str,
        region_name: str,
        public_program: bool,
    ) -> str:
        if not public_program:
            return (
                "Suggerimento preventivo informativo: confrontati con il medico o con il servizio territoriale "
                "se vuoi capire se ha senso per te."
            )
        portal = VERIFIED_REGIONAL_SCREENING_PORTALS.get(region_code.upper())
        if portal is not None:
            return (
                f"Portale istituzionale regionale di {region_name} per gli screening oncologici. "
                "Verifica eventuali inviti della tua ASL o azienda sanitaria."
            )
        if region_code.upper() == "IT":
            return "Disponibilita pubblica generale: verificare il programma locale della propria ASL."
        return (
            "Programma pubblico disponibile con criteri locali ASL/regione. "
            "Verifica disponibilita e invito nella tua area."
        )

    @staticmethod
    def _add_months(source: date, months: int) -> date:
        year = source.year + (source.month - 1 + months) // 12
        month = (source.month - 1 + months) % 12 + 1
        day = min(
            source.day,
            [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1],
        )
        return date(year, month, day)

    def _current_year_completion_map(self, patient_id: UUID) -> dict[UUID, date]:
        year_start, year_end = self._current_year_range()
        return self.repository.list_current_year_completion_dates(
            patient_id,
            year_start=year_start,
            year_end=year_end,
        )

    @staticmethod
    def _care_pathway_for_program(program: ScreeningProgram) -> str:
        if program.code == "preventive_annual_visit":
            return "annual_visit"
        if program.recommendation_level == "shared_decision":
            return "shared_decision"
        if program.recommendation_level == "not_routine":
            return "not_routine"
        return "discuss_with_doctor"

    @staticmethod
    def _current_year_range() -> tuple[date, date]:
        today = date.today()
        return date(today.year, 1, 1), date(today.year, 12, 31)

    @staticmethod
    def _require_profile(user: User):
        profile = resolve_user_profile(user)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    def _require_profile_by_id(self, patient_id: UUID):
        from app.models.patient_profile import PatientProfile

        profile = self.db.get(PatientProfile, patient_id)
        if profile is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        return profile

    @staticmethod
    def _region_code_string(region_code) -> str | None:
        if region_code is None:
            return None
        value = getattr(region_code, "value", region_code)
        return str(value).upper()
