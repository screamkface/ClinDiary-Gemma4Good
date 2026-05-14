# ClinDiary Prevention Center — Conservative Rules Patch

## File modificati / creati

- `apps/mobile/lib/features/prevention_center/domain/prevention_center_engine.dart`
  - Patch conservativa sul file caricato.
  - Mantiene l'architettura esistente e i codici già presenti.
  - Corregge alcune regole troppo larghe o duplicate.
- `apps/mobile/lib/features/prevention_center/domain/prevention_center_policy.dart`
  - Policy regionale minimale usata dall'engine.
  - Default Italia con soglie conservative.
- `apps/mobile/lib/features/prevention_center/domain/prevention_record.dart`
  - Solo se nel repo non esiste già.
  - Serve perché il `ProfileBundle` caricato importa già questo model.

## Regole aggiunte / consolidate

- Mammografia:
  - 50–69: `recommended`, ogni 2 anni.
  - 45–49 e 70–74: `review`, dipendente dal programma regionale.
- Screening cervicale:
  - 25–29: Pap test, ogni 3 anni.
  - 30–64: HPV-DNA, ogni 5 anni.
- Colon-retto:
  - 50–69: FIT/SOF, ogni 2 anni.
  - 70–74: `review`, se policy regionale attiva.
  - Storia personale/familiare rilevante: `colorectal_high_risk_discussion`.
- PSA:
  - 55–69 maschi: shared decision/review.
  - >=70: non routine/review low priority.
  - Storia familiare di primo grado: early discussion.
- DEXA / osso:
  - Donne >=65: `dexa_bone_density` recommended.
  - Postmenopausa + rischio fragilità <65: `early_dexa_discussion`.
  - Uomini >=65 solo se rischio esplicito.
- Fumo:
  - Smoking history review.
  - LDCT solo se età + pack-years + fumatore/ex-fumatore recente sono completi.
  - Se mancano pack-years/anni da stop, solo `lung_risk_data_review`.
- AAA:
  - Maschi 65–75 fumatori/ex: ecografia una tantum recommended.
  - Storia familiare di primo grado: review.
- BMI / rischio metabolico:
  - HbA1c/diabete se BMI >=25 e 35–70 anni, o rischio metabolico/familiare.
- STI / infettivologia:
  - HIV 15–65 almeno una volta/review, recommended se rischio STI.
  - HCV 18–79 una volta/review.
  - STI discussion se rischio attivo.
- Gravidanza/preconcepimento:
  - Follow-up high priority.
  - Review su acido folico senza dosage/prescrizione.
  - Review sicurezza farmaci e vaccini.
- Vaccini:
  - Influenza/COVID esistenti.
  - dTpa adulti ogni 10 anni come review/recommended se record scaduto.
  - Pneumococco >=65 o rischio cronico.
  - Zoster >=65.
  - HPV 9–26 come review/catch-up.

## Scelte conservative

- Nessuna diagnosi.
- Nessun dosage.
- Nessun triage d'emergenza.
- Nessun backend o rete.
- Nessun LLM nell'engine.
- Regole deterministiche.
- I messaggi usano `review`, `discuss`, `confirm timing`, `clinician`, `local screening program`.
- La storia familiare oncologica ad alto rischio ora usa parenti di primo grado quando possibile, inclusi termini italiani: padre, madre, fratello, sorella, figlio, figlia.

## Correzioni rispetto al file caricato

- LDCT non viene più suggerita quando i pack-years sono noti ma sotto soglia.
- Se mancano pack-years o anni da cessazione, l'engine genera solo una review dati, non una raccomandazione LDCT.
- Il rischio polmonare non viene più incluso automaticamente nel rischio cardiometabolico.
- La DEXA early non duplica più l'item legacy `annual_bone_density_review` quando la paziente è postmenopausale e ha rischio fragilità.
- L'acido folico è descritto come discussione preventiva, senza dosage/prescrizione.
- dTpa limitato agli adulti.
- Pneumococco esteso anche agli adulti con condizioni croniche, ma sempre come review.

## Campi nuovi

Nel file caricato erano già presenti:

- `heightCm`
- `weightKg`
- `smokingPackYears`
- `yearsSinceQuitting`
- `takingFolicAcid`
- `preventionRecords`

Non ho aggiunto altri campi al profilo.

## Test da aggiornare nel repo

Non avendo il progetto completo e i test originali, non ho potuto eseguire `flutter test`.
Aggiorna almeno questi test:

- donna 52 anni IT:
  - mammografia recommended
  - HPV screening recommended
  - colon-retto recommended
  - no PSA
- donna 47 anni IT:
  - mammografia extended review
  - no mammografia core recommended
- donna 66 anni:
  - DEXA recommended
  - mammografia core still recommended
  - colon-retto recommended se <=69
- uomo 60 anni:
  - PSA shared decision
  - colon-retto recommended
  - no screening femminili
- uomo 72 anni:
  - PSA not routine/review low
  - colon-retto extended review se policy attiva
- uomo 68 fumatore/ex:
  - AAA ultrasound once recommended
- fumatore 55 anni con 20+ pack-years:
  - LDCT recommended
- fumatore con pack-years mancanti:
  - lung risk data review, non LDCT recommended
- pack-years sotto soglia:
  - no LDCT recommended
- donna postmenopausale <65 con cadute/instabilità:
  - early DEXA review
  - no duplicate annual bone density legacy item
- rischio STI:
  - STI discussion e HIV review/recommended coerenti
- gravidanza/preconcepimento:
  - pregnancy/preconception item high priority
  - folic acid review senza dosage
- birthDate null:
  - no crash

## Comandi da eseguire nel repo

```bash
dart format apps/mobile/lib/features/prevention_center/domain/prevention_center_engine.dart \
  apps/mobile/lib/features/prevention_center/domain/prevention_center_policy.dart \
  apps/mobile/lib/features/prevention_center/domain/prevention_record.dart \
  apps/mobile/lib/features/profile/domain/profile_bundle.dart

flutter analyze
flutter test apps/mobile/test/prevention_center/prevention_center_engine_test.dart
flutter test apps/mobile/test/home/prevention_dossier_screens_test.dart
```
