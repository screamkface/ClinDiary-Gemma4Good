# ClinDiary Prevention Center — Implementation Status

## ✅ Done — Status Overview

| Section | Status | Notes |
|---|---|---|
| Main refactor | ✅ Done | `build()` split into 9 section builders + 6 sub-builders |
| RegionalPreventionPolicy | ✅ Done | IT policy with extended ranges |
| PreventionRecord model | ✅ Done | Integrated into ProfileBundle |
| Helper methods | ✅ Done | See detailed breakdown below |
| Mammography | ✅ Done | Core 50-69 + extended 45-49, 70-74 + high-risk discussion |
| Cervical screening | ✅ Done | Pap 25-29 + HPV-DNA 30-64 |
| Colorectal screening | ✅ Done | FIT core 50-69 + extended 70-74 + high-risk discussion |
| Prostate / PSA | ✅ Done | Shared decision 55-69 + not-routine after 70 |
| Lung cancer / LDCT | ✅ Done | With pack-year check + fallback data review |
| Bone health / DEXA | ✅ Done | Female 65+, early postmenopausal, male risk |
| AAA ultrasound | ✅ Done | Male smoker 65-75 + family history discussion |
| HIV / HCV / STI | ✅ Done | Lifetime checks + risk-based |
| Blood pressure | ✅ Done | Age 18+ annual review |
| Cardiovascular risk | ✅ Done | Age 40+ or risk factors |
| Lipid profile | ✅ Done | Risk-dependent |
| Diabetes / HbA1c | ✅ Done | BMI 25+ or risk factors |
| Kidney/liver bloodwork | ✅ Done | Chronic conditions |
| Annual preventive visit | ✅ Done | All ages |
| Dental check | ✅ Done | All ages, review |
| Eye exam | ✅ Done | Age 40+ |
| Hearing review | ✅ Done | Age 60+ |
| Fall risk review | ✅ Done | Age 65+ or falls/unsteady |
| Mental health check-in | ✅ Done | All ages |
| Skin check discussion | ✅ Done | Risk-based only |
| Medication review | ✅ Done | Conditions or family history |
| Influenza vaccine | ✅ Done | Risk-based |
| COVID booster | ✅ Done | Risk-based |
| dTpa booster | ✅ Done | With date-based overdue detection |
| Pneumococcal vaccine | ✅ Done | Age 65+ |
| Zoster vaccine | ✅ Done | Age 65+ |
| HPV vaccine | ✅ Done | Age 9-26 catch-up |
| Pregnancy vaccines | ✅ Done | Planning review |
| Pregnancy / preconception | ✅ Done | Follow-up, folic acid, medication safety |
| Duplicate prevention | ✅ Done | `seen` code sets per section |
| Status/priority conventions | ✅ Done | recommended/review/shared_decision/seasonal/not_routine |
| Risk token detection | ✅ Done | All token lists implemented |
| Tests | ✅ Done | 56 tests covering all minimum cases |
| Documentation | ✅ Done | `docs/prevention_center_rules.md` + `REMAINING_WORK.md` |

## ✅ Helper Methods Detail

| Helper | Status | Location |
|---|---|---|
| `_hasRecentRecord(bundle, codes, referenceDate, maxAge)` | ✅ Done | `prevention_center_engine.dart` |
| `_hasEverRecord(bundle, codes)` | ✅ Done | `prevention_center_engine.dart` |
| `_yearsSince(DateTime, DateTime)` | ✅ Done | `prevention_center_engine.dart` |
| `_bmi(PatientProfile)` | ✅ Done | `prevention_center_engine.dart` |
| `_hasObesityOrOverweight(bundle)` | ✅ Done | `prevention_center_engine.dart` |
| `_hasSmokingPackYearRisk(bundle)` | ✅ Done | `prevention_center_engine.dart` |
| `_quitSmokingWithinYears(bundle, years, referenceDate)` | ✅ Done | `prevention_center_engine.dart` |
| `_containsAnyCondition(bundle, tokens)` | ✅ Done | `prevention_center_engine.dart` |
| `_containsAnyMedication(bundle, tokens)` | ✅ Done | `prevention_center_engine.dart` |
| `_containsAnyFamilyHistory(familyHistory, tokens)` | ✅ Done | `prevention_center_engine.dart` |
| `_hasFirstDegreeFamilyHistory(bundle, tokens)` | ✅ Done | `prevention_center_engine.dart` |

## ✅ Token Lists Detail

| Group | Tokens | Status |
|---|---|---|
| Cardiometabolic conditions | hypertension, blood pressure, diabetes, prediabetes, cholesterol, dyslipidemia, cardio, heart, vascular, stroke, myocardial, infarction, coronary | ✅ Done |
| Cardiometabolic family history | hypertension, diabetes, cholesterol, dyslipidemia, cardio, heart, stroke, vascular, myocardial, coronary | ✅ Done |
| Thyroid conditions | thyroid, hypothyroid, hyperthyroid, hashimoto, graves | ✅ Done |
| Thyroid medications | levothyroxine, thyroxine | ✅ Done |
| Bone risk conditions | osteoporosis, osteopenia, fracture, fragility, menopause | ✅ Done |
| Bone risk medications | steroid, prednisone, cortisone, dexamethasone | ✅ Done |
| Colon high-risk | colorectal, colon cancer, bowel cancer, polyps, inflammatory bowel disease, ulcerative colitis, crohn, familial adenomatous, lynch | ✅ Done |
| Breast high-risk | breast cancer, brca, ovarian cancer, genetic mutation, her2 | ✅ Done |
| AAA/aortic | aneurysm, aortic, abdominal aortic aneurysm, aaa | ✅ Done |
| Pulmonary | copd, emphysema, chronic bronchitis, pulmonary, lung disease | ✅ Done |

## 🚧 Future Improvements

| Feature | Status | Notes |
|---|---|---|
| PreventionRecords wired to suppress recommendations | 🚧 Ready | `_hasRecentRecord` + `_hasEverRecord` implemented, but not yet used by builders |
| Regional policy for non-IT regions | 🚧 Not started | Currently defaults to conservative international ranges |
| Last exam date fields in profile | 🚧 Not started | Would enable "next due" calculations |
| Hysterectomy/cervix status field | 🚧 Not started | Currently no way to skip cervical screening |
| Structured `firstDegreeRelative` field | 🚧 Not started | `_hasFirstDegreeFamilyHistory` uses free-text matching |
| `steroidUse`/`immunosuppressed` flags | 🚧 Not started | Would improve bone/vaccine rules |
| Genetic mutation fields (BRCA, Lynch) | 🚧 Not started | Would improve high-risk detection |
| `cvdRiskScore` (SCORE, Framingham) | 🚧 Not started | Would improve CV risk stratification |
| Localization (Italian/English copy) | 🚧 Not started | All copy is English |
| Guideline version metadata | 🚧 Not started | No source attribution on rules |

## ✅ Acceptance Criteria

| Criterion | Status |
|---|---|
| Code compiles | ✅ flutter analyze: no issues |
| Existing tests pass | ✅ 56/56 pass (2 pre-existing unrelated failures) |
| New tests pass | ✅ |
| No crashes with null age/sex/birthDate/etc | ✅ Tested: null birthDate, empty sex, empty bundle |
| Deterministic (no LLM/network) | ✅ All rules are hardcoded |
| Medical copy uses careful language | ✅ "review", "discuss", "confirm timing" |
| No alarming messages | ✅ Cautious wording throughout |

---

## ✅ Status Updates (pass 5)

| New Feature | Status | Details |
|---|---|---|
| Eye exam: risk-based status | ✅ Done | Diabetes/glaucoma/cataract → `recommended`/`high`. Healthy → `review`/`low`. |
| Pneumococcal dynamic priority | ✅ Done | COPD, diabetes, heart/kidney/liver disease → `high`. Default → `normal`. |
| Duplicate bone density fix | ✅ Done | `annual_bone_density_review` soppresso quando `dexa_bone_density` (≥65) è generato. |
| PSA cadence in suppression map | ✅ Done | `psa_high_risk_discussion` e `psa_shared_decision` aggiunti a `_cadenceForCode`. |
| Tests | ✅ 63 total | +3: eye diabetic/healthy, pneumococcal chronic risk |

## ✅ Status Updates (pass 6)

| New Feature | Status | Details |
|---|---|---|
| Regional policy US | ✅ Done | USPSTF-based: mammography 50-74, colorectal 50-75, cervical 21-65 (Pap 21-29, HPV 30-65) |
| Regional policy UK | ✅ Done | NHS-based: mammography 50-71, colorectal 60-74, cervical 25-64 (HPV primary from 25) |
| Cervical Pap/HPV separation | ✅ Done | `cervicalPapStartAge` e `cervicalHpvStartAge` separati nel policy. |
| Tests | ✅ 65 total | +2: US region (mammo + Pap/HPV), UK region (colorectal start + HPV primary) |

*Last updated: 2026-05-14*
