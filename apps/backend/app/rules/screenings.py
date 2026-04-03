from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from app.models.enums import AlcoholUse, BiologicalSex, ConditionStatus
from app.models.patient_profile import PatientProfile
from app.models.screening_program import ScreeningProgram
from app.models.screening_rule import ScreeningRule


@dataclass(slots=True)
class ScreeningEligibility:
    eligible: bool
    reason: str


class ScreeningRuleEngine:
    def evaluate(
        self,
        profile: PatientProfile,
        program: ScreeningProgram,
        *,
        reference_date: date | None = None,
    ) -> ScreeningEligibility:
        today = reference_date or date.today()
        age = self._compute_age(profile.birth_date, today)
        bmi = self._compute_bmi(profile.height_cm, profile.weight_kg)
        family_history = {item.condition_name.lower() for item in profile.family_history_entries}
        active_conditions = {
            item.name.lower()
            for item in profile.conditions
            if item.status != ConditionStatus.RESOLVED
        }
        active_conditions.update(
            item.notes.lower()
            for item in profile.conditions
            if item.notes and item.status != ConditionStatus.RESOLVED
        )
        specific_program_result = self._evaluate_program_specific_defaults(
            profile=profile,
            program=program,
            age=age,
            bmi=bmi,
        )
        if specific_program_result is not None:
            return specific_program_result

        rules = [rule for rule in program.rules if rule.active]
        if not rules:
            return self._evaluate_program_defaults(profile, program, age)

        for rule in rules:
            if self._matches_rule(
                profile,
                rule,
                age,
                bmi,
                family_history,
                active_conditions,
            ):
                return ScreeningEligibility(eligible=True, reason=rule.description)

        return ScreeningEligibility(
            eligible=False,
            reason="Il profilo attuale non rientra nei criteri deterministici di eleggibilita per questo screening.",
        )

    @staticmethod
    def _compute_age(birth_date: date | None, reference_date: date) -> int | None:
        if birth_date is None:
            return None
        years = reference_date.year - birth_date.year
        if (reference_date.month, reference_date.day) < (birth_date.month, birth_date.day):
            years -= 1
        return years

    def _evaluate_program_defaults(
        self,
        profile: PatientProfile,
        program: ScreeningProgram,
        age: int | None,
    ) -> ScreeningEligibility:
        if program.target_sex is not None and profile.biological_sex != program.target_sex:
            return ScreeningEligibility(
                eligible=False,
                reason="Programma riservato a un diverso target biologico.",
            )
        if age is None:
            return ScreeningEligibility(
                eligible=False,
                reason="Eta non disponibile: completa la data di nascita per calcolare gli screening consigliati.",
            )
        if program.min_age is not None and age < program.min_age:
            return ScreeningEligibility(eligible=False, reason="Eta inferiore ai criteri del programma.")
        if program.max_age is not None and age > program.max_age:
            return ScreeningEligibility(eligible=False, reason="Eta oltre il range del programma.")
        return ScreeningEligibility(
            eligible=True,
            reason=program.explanation or program.description,
        )

    @staticmethod
    def _compute_bmi(height_cm: float | None, weight_kg: float | None) -> float | None:
        if height_cm is None or weight_kg is None or height_cm <= 0 or weight_kg <= 0:
            return None
        height_m = height_cm / 100
        return weight_kg / (height_m * height_m)

    def _matches_rule(
        self,
        profile: PatientProfile,
        rule: ScreeningRule,
        age: int | None,
        bmi: float | None,
        family_history: set[str],
        active_conditions: set[str],
    ) -> bool:
        if rule.target_sex is not None and profile.biological_sex != rule.target_sex:
            return False
        if rule.min_age is not None and (age is None or age < rule.min_age):
            return False
        if rule.max_age is not None and (age is None or age > rule.max_age):
            return False
        if rule.smoker_required is not None and profile.smoker != rule.smoker_required:
            return False
        if rule.family_history_keyword is not None:
            keyword = rule.family_history_keyword.lower()
            if not any(keyword in item for item in family_history):
                return False
        if rule.condition_keyword is not None:
            keyword = rule.condition_keyword.lower()
            if not any(keyword in item for item in active_conditions):
                return False
        if rule.alcohol_use_required is not None and profile.alcohol_use != rule.alcohol_use_required:
            return False
        if (
            rule.activity_level_required is not None
            and profile.activity_level != rule.activity_level_required
        ):
            return False
        if rule.min_bmi is not None and (bmi is None or bmi < rule.min_bmi):
            return False
        return True

    def _evaluate_program_specific_defaults(
        self,
        *,
        profile: PatientProfile,
        program: ScreeningProgram,
        age: int | None,
        bmi: float | None,
    ) -> ScreeningEligibility | None:
        code = getattr(program, "code", None)
        if code == "osteoporosis_screening":
            return self._evaluate_osteoporosis(profile, age=age, bmi=bmi)
        if code == "lung_cancer_screening":
            return self._evaluate_lung_cancer(profile, age=age)
        if code == "abdominal_aortic_aneurysm_screening":
            return self._evaluate_aaa(profile, age=age)
        if code == "falls_prevention_review":
            return self._evaluate_falls_prevention(profile, age=age)
        if code == "sti_risk_assessment":
            return self._evaluate_sti_risk(profile, age=age)
        if code == "preconception_review":
            return self._evaluate_preconception(profile, age=age)
        if code == "pregnancy_review":
            return self._evaluate_pregnancy(profile, age=age)
        if code == "prostate_psa_shared_decision":
            return self._evaluate_prostate_psa(profile, age=age)
        if code == "skin_cancer_shared_decision":
            return self._evaluate_skin_cancer_shared_decision(profile, age=age)
        if code == "vision_screening_shared_decision":
            return self._evaluate_vision_shared_decision(profile, age=age)
        return None

    @staticmethod
    def _evaluate_osteoporosis(
        profile: PatientProfile,
        *,
        age: int | None,
        bmi: float | None,
    ) -> ScreeningEligibility:
        if profile.biological_sex != BiologicalSex.FEMALE:
            return ScreeningEligibility(
                eligible=False,
                reason="Questa valutazione deterministica e impostata per profili femminili; per altri profili va personalizzata con il medico.",
            )
        if age is None:
            return ScreeningEligibility(
                eligible=False,
                reason="Eta non disponibile: completa la data di nascita per valutare il rischio osseo.",
            )
        if age >= 65:
            return ScreeningEligibility(
                eligible=True,
                reason="Dopo i 65 anni conviene discutere lo screening per osteoporosi o densitometria ossea.",
            )
        risk_flags = [
            profile.postmenopausal,
            profile.smoker or profile.former_smoker,
            profile.alcohol_use == AlcoholUse.HIGH,
            profile.fragility_fracture_history,
            bmi is not None and bmi < 21,
        ]
        if age >= 50 and profile.postmenopausal and any(risk_flags[1:]):
            return ScreeningEligibility(
                eligible=True,
                reason="Con post-menopausa e fattori di rischio osseo dichiarati, vale la pena discutere una valutazione per osteoporosi.",
            )
        return ScreeningEligibility(
            eligible=False,
            reason="Con i dati attuali non emergono criteri sufficienti per suggerire automaticamente una valutazione ossea mirata.",
        )

    @staticmethod
    def _evaluate_lung_cancer(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if age is None:
            return ScreeningEligibility(
                eligible=False,
                reason="Eta non disponibile: completa il profilo per valutare lo screening del polmone.",
            )
        if age < 50 or age > 80:
            return ScreeningEligibility(
                eligible=False,
                reason="Lo screening del polmone non rientra nel range di eta tipico supportato da questa regola.",
            )
        if profile.smoking_pack_years is None or profile.smoking_pack_years < 20:
            return ScreeningEligibility(
                eligible=False,
                reason="Per questa regola servono almeno 20 pack-years di esposizione tabagica.",
            )
        if profile.smoker:
            return ScreeningEligibility(
                eligible=True,
                reason="Eta e storia tabagica dichiarata rientrano nei criteri per discutere uno screening del polmone.",
            )
        if not profile.former_smoker:
            return ScreeningEligibility(
                eligible=False,
                reason="Lo screening del polmone richiede una storia tabagica attiva o pregressa rilevante.",
            )
        if profile.years_since_quitting is None:
            return ScreeningEligibility(
                eligible=False,
                reason="Per un ex fumatore serve indicare da quanti anni hai smesso per valutare lo screening del polmone.",
            )
        if profile.years_since_quitting > 15:
            return ScreeningEligibility(
                eligible=False,
                reason="Con cessazione del fumo da oltre 15 anni questa regola non suggerisce automaticamente lo screening del polmone.",
            )
        return ScreeningEligibility(
            eligible=True,
            reason="Eta, esposizione tabagica e anni dalla cessazione rientrano nei criteri per discutere lo screening del polmone.",
        )

    @staticmethod
    def _evaluate_aaa(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if profile.biological_sex != BiologicalSex.MALE:
            return ScreeningEligibility(
                eligible=False,
                reason="Questa regola e calibrata per profili maschili, dove il criterio deterministico e meglio definito.",
            )
        if age is None:
            return ScreeningEligibility(
                eligible=False,
                reason="Eta non disponibile: completa il profilo per valutare lo screening dell'aorta addominale.",
            )
        if age < 65 or age > 75:
            return ScreeningEligibility(
                eligible=False,
                reason="La regola deterministica per aneurisma aortico addominale si applica soprattutto tra 65 e 75 anni.",
            )
        if profile.smoker or profile.former_smoker or (profile.smoking_pack_years or 0) > 0:
            return ScreeningEligibility(
                eligible=True,
                reason="Eta e storia tabagica dichiarata rendono appropriato discutere un'ecografia dell'aorta addominale.",
            )
        return ScreeningEligibility(
            eligible=False,
            reason="Senza storia tabagica rilevante questa regola non suggerisce automaticamente lo screening per aneurisma aortico addominale.",
        )

    @staticmethod
    def _evaluate_falls_prevention(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if age is None:
            return ScreeningEligibility(
                eligible=False,
                reason="Eta non disponibile: completa il profilo per valutare il rischio cadute.",
            )
        if age < 65:
            return ScreeningEligibility(
                eligible=False,
                reason="La valutazione strutturata del rischio cadute viene attivata soprattutto dai 65 anni in su.",
            )
        falls_last_year = profile.falls_last_year or 0
        if falls_last_year >= 1 or profile.feels_unsteady:
            return ScreeningEligibility(
                eligible=True,
                reason="Cadute recenti o sensazione di instabilita meritano una revisione di equilibrio, forza e sicurezza domestica.",
            )
        return ScreeningEligibility(
            eligible=False,
            reason="Con i dati attuali non emergono indicatori dichiarati di rischio cadute che attivino questa regola.",
        )

    @staticmethod
    def _evaluate_sti_risk(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if age is not None and age < 15:
            return ScreeningEligibility(
                eligible=False,
                reason="La valutazione MST personalizzata non viene attivata automaticamente sotto i 15 anni.",
            )
        if profile.sexually_active is not True:
            return ScreeningEligibility(
                eligible=False,
                reason="I test MST personalizzati vengono suggeriti solo se nel profilo risulta attivita sessuale o esposizione rilevante.",
            )
        if any(
            (
                profile.new_or_multiple_partners,
                profile.partner_with_sti,
                profile.sex_with_men,
                profile.sti_or_exposure_concerns,
            )
        ):
            return ScreeningEligibility(
                eligible=True,
                reason="Nel profilo sono presenti fattori di rischio o esposizione che rendono utile discutere test MST mirati.",
            )
        return ScreeningEligibility(
            eligible=False,
            reason="Con i dati attuali non emergono fattori di rischio sessuale sufficienti per attivare automaticamente i test MST.",
        )

    @staticmethod
    def _evaluate_preconception(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if profile.biological_sex != BiologicalSex.FEMALE:
            return ScreeningEligibility(
                eligible=False,
                reason="Il percorso preconcezionale automatico e limitato ai profili femminili perche richiede un contesto riproduttivo specifico.",
            )
        if age is None or age < 18 or age > 45:
            return ScreeningEligibility(
                eligible=False,
                reason="La regola preconcezionale e attivata solo in una fascia fertile adulta compatibile con il contesto dichiarato.",
            )
        if profile.trying_to_conceive:
            if profile.taking_folic_acid:
                return ScreeningEligibility(
                    eligible=True,
                    reason="Se stai cercando una gravidanza, conviene rivedere farmaci, vaccini e condizioni note anche se i folati sono gia presenti.",
                )
            return ScreeningEligibility(
                eligible=True,
                reason="Se stai cercando una gravidanza, vale la pena discutere folati, farmaci attivi, vaccini e condizioni note prima del concepimento.",
            )
        return ScreeningEligibility(
            eligible=False,
            reason="Questa regola si attiva solo se nel profilo hai indicato che stai cercando una gravidanza.",
        )

    @staticmethod
    def _evaluate_pregnancy(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if profile.biological_sex != BiologicalSex.FEMALE:
            return ScreeningEligibility(
                eligible=False,
                reason="La revisione prevenzione in gravidanza richiede un contesto ostetrico e resta limitata ai profili pertinenti.",
            )
        if age is None or age < 18 or age > 50:
            return ScreeningEligibility(
                eligible=False,
                reason="La regola gravidanza si attiva solo in una fascia adulta compatibile con il contesto dichiarato.",
            )
        if profile.currently_pregnant:
            return ScreeningEligibility(
                eligible=True,
                reason="Con gravidanza in corso conviene rivedere con il medico o l'ostetrica vaccini, farmaci e follow-up preventivi.",
            )
        return ScreeningEligibility(
            eligible=False,
            reason="Questa regola si attiva solo se nel profilo e indicata una gravidanza in corso.",
        )

    @staticmethod
    def _evaluate_prostate_psa(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if profile.biological_sex != BiologicalSex.MALE:
            return ScreeningEligibility(
                eligible=False,
                reason="La decisione condivisa sul PSA e limitata ai profili maschili.",
            )
        if age is None or age < 55 or age > 69:
            return ScreeningEligibility(
                eligible=False,
                reason="La decisione condivisa sul PSA viene proposta soprattutto tra 55 e 69 anni.",
            )
        return ScreeningEligibility(
            eligible=True,
            reason="Tra 55 e 69 anni il PSA va discusso caso per caso con il medico, senza automatismi forti.",
        )

    @staticmethod
    def _evaluate_skin_cancer_shared_decision(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if age is None or age < 18:
            return ScreeningEligibility(
                eligible=False,
                reason="La discussione su cute e melanoma non viene attivata automaticamente in questo profilo.",
            )
        haystack = " ".join(
            [
                (profile.occupation or "").lower(),
                (profile.exercise_habits or "").lower(),
                (profile.symptom_triggers or "").lower(),
            ]
        )
        if any(token in haystack for token in ("sole", "solare", "outdoor", "agric", "cantiere", "mare", "montagna", "uv")):
            return ScreeningEligibility(
                eligible=True,
                reason="Nel profilo emergono possibili esposizioni solari o outdoor che possono meritare una discussione prudente sulla cute.",
            )
        return ScreeningEligibility(
            eligible=False,
            reason="Senza fattori specifici dichiarati ClinDiary non attiva automaticamente un controllo dermatologico di screening.",
        )

    @staticmethod
    def _evaluate_vision_shared_decision(profile: PatientProfile, *, age: int | None) -> ScreeningEligibility:
        if age is None or age < 65:
            return ScreeningEligibility(
                eligible=False,
                reason="La discussione sul controllo visivo automatico viene considerata soprattutto dopo i 65 anni.",
            )
        return ScreeningEligibility(
            eligible=True,
            reason="Dopo i 65 anni il controllo visivo negli asintomatici va personalizzato e discusso senza automatismi forti.",
        )
