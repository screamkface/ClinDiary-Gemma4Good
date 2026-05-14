# ClinDiary Prevention Center Rules

## Overview

The Prevention Center is a **deterministic, local-only engine** that generates
preventive health recommendations based on the user's `ProfileBundle`. No LLM
calls, no network requests. All rules are coded explicitly in
`PreventionCenterEngine`.

## Rule Categories

| Category | Section | Examples |
|---|---|---|
| General prevention | annualExams | Blood pressure review, cardiologist review |
| Cancer screening | annualExams | Mammography, cervical, colorectal, lung LDCT |
| Bone health | annualExams | DEXA scan, bone density discussion |
| Vascular screening | annualExams | AAA ultrasound |
| Infectious disease | annualExams | HIV, HCV, STI screening |
| Metabolic screening | annualExams | Diabetes / HbA1c |
| Laboratory / visits | visitsAndControls | Bloodwork, CV risk review, lipid panel |
| Vaccines | vaccines | Influenza, COVID, dTpa, pneumococcal, zoster, HPV |
| Pregnancy / preconception | pregnancyAndPreconception | Follow-up, folic acid, medication safety, vaccine planning |
| Shared decisions | sharedDecisions | PSA, family history review, breast high-risk |
| Seasonal | seasonalChecks | Generic seasonal prevention review |
| Follow-up | followUpReminders | Condition follow-up, medication review |

## Data Inputs Used

- `birthDate` → age calculation (nullable; engine handles null gracefully)
- `biologicalSex` → sex-normalized to `female` / `male` / `unknown`
- `smoker`, `formerSmoker`, `smokingPackYears`, `yearsSinceQuitting`
- `postmenopausal`, `fragilityFractureHistory`, `fallsLastYear`, `feelsUnsteady`
- `sexuallyActive`, `newOrMultiplePartners`, `partnerWithSti`, `sexWithMen`, `stiOrExposureConcerns`
- `currentlyPregnant`, `tryingToConceive`, `takingFolicAcid`
- `heightCm`, `weightKg` → BMI
- `medicalConditions` → token-matched (`MedicalConditionItem.name`, `.status`, `.notes`)
- `medications` → token-matched (`MedicationItem.name`, `.dosage`, `.frequency`, `.route`, `.notes`)
- `familyHistory` → token-matched (`FamilyHistoryItem.relation`, `.conditionName`, `.notes`)
- `vaccinations` → basic tetanus record check
- `regionCode` → `RegionalPreventionPolicy` selection

## Status / Priority Conventions

| status | Meaning | When used |
|---|---|---|
| `recommended` | Clear eligibility, broadly accepted | Age-based screenings, clear risk |
| `review` | Clinician / local policy dependent | Extended ranges, risk-dependent decisions |
| `shared_decision` | Individual decision, discuss pros/cons | PSA screening |
| `seasonal` | Generic seasonal reminder | Seasonal vaccine review |
| `not_routine` | Avoid routine screening | PSA after 70 |

| priority | Visual | When used |
|---|---|---|
| `high` | Red border | Meaningful risk, clear eligibility |
| `normal` | Primary color | Standard age/risk based |
| `low` | Subtle | Optional, non-urgent |

## Regional Policy Approach

`RegionalPreventionPolicy` encodes age ranges and extension flags per region.
Currently only `IT` (Italy) has custom values:

| Parameter | Default | Italy (IT) |
|---|---|---|
| Mammography core | 50-69 | 50-69 (recommended) |
| Mammography extended 45-49 | no | yes (review) |
| Mammography extended 70-74 | no | yes (review) |
| Colorectal core | 50-69 | 50-69 (recommended) |
| Colorectal extended 70-74 | no | yes (review) |
| Cervical Pap | 25-29 | 25-29 (recommended) |
| Cervical HPV | 30-64 | 30-64 (recommended) |
| LDCT lung | 50-80 | 50-80 |
| AAA ultrasound | 65-75 | 65-75 |

## Implemented Screening / Vaccine Rules

### Cancer screenings

| Code | Condition | Status | Priority |
|---|---|---|---|
| `mammography_screening` | Female 50-69 | recommended | high |
| `mammography_extended_45_49_discussion` | Female 45-49, regional | review | normal |
| `mammography_extended_70_74_discussion` | Female 70-74, regional | review | normal |
| `cervical_pap_screening` | Female 25-29 | recommended | high |
| `cervical_hpv_screening` | Female 30-64 | recommended | high |
| `annual_colorectal_screening_discussion` | 50-69 (FIT pathway) | recommended | high |
| `colorectal_extended_discussion` | 70-74, regional | review | normal |
| `colorectal_high_risk_discussion` | High-risk profile | review | high |
| `psa_shared_decision` | Male 55-69 | review (shared_decision) | normal |
| `psa_not_routine_after_70` | Male 70+ | review | low |
| `lung_ldct_screening` | 50-80, 20+ pack-years | recommended | high |
| `lung_risk_data_review` | Smoker, no pack-year data | review | normal |
| `breast_high_risk_screening_discussion` | Female, high-risk family history | review (shared_decision) | high |

### Bone health

| Code | Condition | Status | Priority |
|---|---|---|---|
| `dexa_bone_density` | Female 65+ | recommended | normal |
| `annual_bone_density_review` | Female 65+/postmenopausal/risk | review | normal |
| `early_dexa_discussion` | Postmenopausal <65 with risk | review | normal/high |
| `male_bone_density_discussion` | Male 65+ with risk | review | normal |

### Vascular

| Code | Condition | Status | Priority |
|---|---|---|---|
| `aaa_ultrasound_once` | Male 65-75, smoker | recommended | normal |
| `aaa_family_history_discussion` | Male 65-75, family history | review | normal |

### Infectious disease

| Code | Condition | Status | Priority |
|---|---|---|---|
| `hiv_once_lifetime` | 15-65 | review / recommended | normal |
| `hcv_once_lifetime` | 18-79 | review | normal |
| `sti_screening_discussion` | STI risk active | review | normal |
| `young_woman_sti_screening` | Female <=24, sexually active | review | normal |

### Cardiovascular / metabolic

| Code | Condition | Status | Priority |
|---|---|---|---|
| `annual_blood_pressure_review` | 18+ | review / recommended | normal/high |
| `annual_cardiology_review` | 35+ | review / recommended | normal/high |
| `cardiovascular_risk_review` | 40+ or risk | review / recommended | normal/high |
| `lipid_profile_review` | 40+ or risk | review / recommended | normal/high |
| `diabetes_hba1c_screening` | 35-70, BMI>=25 or risk | recommended | normal |
| `annual_bloodwork_review` | 18+ | review | normal |
| `basic_bloodwork_review` | Chronic conditions | review | normal |

### Vaccines

| Code | Condition | Status | Priority |
|---|---|---|---|
| `annual_influenza_review` | 60+, smoker, risk, pregnant | recommended | normal |
| `covid_booster_review` | Risk, conditions | review | normal |
| `dtpa_booster_review` | All adults | review | normal |
| `pneumococcal_vaccine_review` | 65+ | review | normal |
| `zoster_vaccine_review` | 65+ | review | normal |
| `hpv_vaccine_review` | 9-26 | review | normal |

### Pregnancy / preconception

| Code | Condition | Status | Priority |
|---|---|---|---|
| `pregnancy_preconception_review` | Pregnant / trying | recommended | high |
| `preconception_folic_acid` | Pregnant / trying | recommended | high |
| `pregnancy_medication_review` | Pregnant / trying | recommended | high |
| `pregnancy_vaccine_planning` | Pregnant / trying | review | normal |

### General / follow-up

| Code | Condition | Status | Priority |
|---|---|---|---|
| `annual_general_visit` | All ages | recommended | normal/high |
| `annual_eye_exam` | 40+ | review | low |
| `fall_risk_review` | 65+ or falls/unsteady | review / recommended | normal/high |
| `hearing_review` | 60+ | review | low |
| `family_history_review` | Any family history | review (shared_decision) | normal |
| `condition_followup` | Active medical conditions | recommended | normal |
| `medication_review` | Conditions or family history | review | normal |
| `seasonal_vaccine_review` | Always | seasonal | low |

## Medical Safety Notes

- The engine **never diagnoses, prescribes, or recommends treatment**.
- All recommendations use careful language: "review", "discuss", "confirm timing", "local program".
- `recommended` status is used only when the rule is broadly accepted (e.g. Italy's
  national screening programs).
- `review` status means the user should discuss with a clinician before acting.
- `shared_decision` items explicitly describe the choice being offered (e.g. PSA).
- No AI or network calls are involved — the engine is fully deterministic.

## Architecture

```
build(ProfileBundle, regionCode, generatedAt)
├── _buildAnnualVisit(bundle, age, sex)
├── _buildAnnualExams(bundle, age, sex, ...)
│   ├── _buildMammographyItems(...)
│   ├── _buildLungCancerItems(...)
│   ├── _buildAaaItems(...)
│   ├── _buildBoneHealthItems(...)
│   ├── _buildInfectiousDiseaseItems(...)
│   └── _buildDiabetesScreeningItems(...)
├── _buildVisitsAndControls(bundle, age, sex, ...)
├── _buildVaccines(bundle, age, sex, ...)
├── _buildVaccineRegistry(bundle)
├── _buildPregnancyItems(bundle, age, sex, ...)
├── _buildSharedDecisionItems(bundle, age, sex, ...)
├── _buildSeasonalChecks()
└── _buildFollowUpItems(bundle)
```

Each section builder uses a `seen` set for in-section deduplication.
Risk helpers (`_hasCardiometabolicRisk`, `_hasStiRisk`, etc.) are reused.

## Future Improvements

### Prevention history records
`PreventionRecord` model exists in `prevention_record.dart` but is not yet
wired to `ProfileBundle`. Once integrated, helpers like `_hasRecentRecord()`
and `_hasEverRecord()` can suppress items already completed.

### Regional policy files
Only `IT` has a custom `RegionalPreventionPolicy`. Other region codes default
to conservative international ranges. Region-specific JSON files could be
added for fine-grained local differences.

### Last exam date tracking
No fields exist for last mammography, Pap, colonoscopy, DEXA date, etc.
Adding these to the profile would allow the engine to show "next due" dates.

### Pack-year smoking model
`smokingPackYears` and `yearsSinceQuitting` exist but are optional. The LDCT
rule requires pack-years >= 20. Fallback `lung_risk_data_review` is shown when
the user is a smoker but pack-year data is missing.

### BMI support
`heightCm` and `weightKg` exist. `_bmi()` helper is implemented.
Diabetes screening uses BMI >= 25 as a trigger.
No height/weight → no BMI → falls back to condition/family-history-based triggers.

### Family-history degree support
`FamilyHistoryItem.relation` is a free-text string. No structured degree
(first-degree vs. second-degree) parsing is done. `_hasFirstDegreeFamilyHistory()`
is not implemented.

### Clinician-reviewed guideline versioning
No versioning system exists. The engine defines rules directly in Dart code.

### Localization for Italian / English copy
Currently all recommendation copy is in English. Italian translations
could be added through the existing Flutter l10n pipeline.

### Missing profile fields that would improve precision
- `lastMammogramDate`, `lastPapDate`, `lastColonoscopyDate`
- `hysterectomy` / `cervixPresent`
- `gestationalAge` / `dueDate`
- `firstDegreeRelative` structured field
- Smoking `quitDate` (currently only `yearsSinceQuitting`)
- `steroidUse` / `immunosuppressed` boolean flags
- Known genetic mutations (BRCA, Lynch, FAP)
- Personal history of polyps
- `cvdRiskScore` (SCORE, Framingham)
