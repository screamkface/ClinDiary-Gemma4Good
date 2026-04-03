# ClinDiary - Report Completo Stato Attuale

Data: 3 aprile 2026

## 1. Executive summary

ClinDiary e` una piattaforma mobile-first per la salute personale con backend centralizzato. Oggi copre:

- diario clinico giornaliero
- timeline sanitaria unica
- archivio documentale con parsing e ricerca
- recap AI prudenti e report pre-visita
- motore deterministico di prevenzione e screening
- gestione terapie e aderenza
- notifiche e alert center
- dossier salute aggregato
- sync wearable via Health Connect / Apple Health
- modulo device clinici Wave 1
- modello freemium con `free` e `AI Plus`

L'architettura e` un **modular monolith**:

- backend FastAPI
- worker Celery
- beat scheduler
- PostgreSQL + pgvector
- Redis
- MinIO
- app mobile Flutter

Non e` un insieme di microservizi separati.

## 2. Obiettivo del prodotto

ClinDiary non e` solo un diario sintomi. Il prodotto oggi e` progettato come:

- cartella clinica personale mobile
- hub per documenti sanitari
- strumento di organizzazione clinica e pre-visita
- layer di prevenzione spiegabile
- layer AI prudente per sintesi e retrieval documentale

Il perimetro attuale evita diagnosi automatiche e mantiene separati:

- logica deterministica clinica
- narrativa AI

## 3. Funzioni attuali dell'app

## 3.1. Account, autenticazione e onboarding

Funzioni presenti:

- registrazione account
- login
- refresh token rotation
- logout
- reset password
- onboarding iniziale
- consenso dati sanitari
- consenso separato per uso AI esterna
- supporto Google Sign-In lato mobile e backend compatibile

Moduli principali:

- backend auth: `apps/backend/app/api/v1/auth.py`
- modelli: `user.py`, `refresh_token.py`, `password_reset_token.py`, `user_onboarding.py`
- mobile: `apps/mobile/lib/features/auth/`, `apps/mobile/lib/features/onboarding/`

## 3.2. Profilo clinico e profili familiari

Funzioni presenti:

- profilo paziente principale
- profili familiari/gestiti
- dati anagrafici e contesto clinico
- allergie
- patologie note
- farmaci attivi
- familiarita`
- storico vaccinale
- problemi/episodi clinici
- campi estesi per prevenzione avanzata
- campi preconcezione/gravidanza

Il profilo non e` solo descrittivo: aggiorna il motore deterministico di:

- screening
- prevenzione
- follow-up
- notifiche dipendenti dal profilo

Moduli principali:

- backend profile: `apps/backend/app/api/v1/profile.py`
- modelli: `patient_profile.py`, `allergy.py`, `medical_condition.py`, `family_history.py`, `vaccination_record.py`, `clinical_episode.py`
- mobile: `apps/mobile/lib/features/profile/`

## 3.3. Diario giornaliero, sintomi e parametri

Funzioni presenti:

- diario giornaliero
- sintomi
- parametri vitali manuali
- note libere
- check-in giornaliero
- dettaglio giorno
- storico per giorno
- storico con calendario e marker attività

Tipi di dato gestiti:

- sintomi
- pressione
- temperatura
- peso
- glicemia
- saturazione
- battito
- note cliniche personali

Moduli principali:

- backend: `daily_entries.py`, `symptoms.py`, `vitals.py`, `history.py`
- modelli: `daily_entry.py`, `symptom_entry.py`, `vital_sign_entry.py`
- mobile: `apps/mobile/lib/features/daily_journal/`, `history/`

## 3.4. Timeline sanitaria

Funzioni presenti:

- timeline clinica aggregata
- eventi organizzati per giorno
- filtri rapidi per categoria
- eventi da:
  - diario
  - documenti
  - farmaci
  - alert
  - prevenzione
  - report

Moduli principali:

- backend: `timeline.py`
- modelli: `timeline_event.py`
- mobile: `apps/mobile/lib/features/timeline/`

## 3.5. Documenti clinici

Funzioni presenti:

- upload PDF/JPG/PNG
- archivio a cartelle
- cartelle annidate
- breadcrumb
- spostamento file tra cartelle
- ricerca documenti
- viewer con URL firmata
- dettaglio documento
- testo estratto OCR collassato di default
- parsing referti laboratorio e imaging
- revisione manuale del parsing
- ricerca documentale AI con citazioni

Pipeline documentale:

1. upload file
2. verifica MIME reale
3. hash SHA-256
4. storage MinIO o vault locale
5. estrazione testo
6. OCR se necessario
7. parsing deterministico
8. review manuale opzionale
9. indicizzazione RAG a chunk

Modalita` storage:

- `free`: file salvati localmente sul dispositivo
- `AI Plus`: file in cloud ClinDiary

Regole importanti:

- il vault locale `free` e` scoped per utente/profilo
- in downgrade i documenti cloud restano leggibili in sola lettura

Moduli principali:

- backend API: `documents.py`
- modelli: `clinical_document.py`, `document_folder.py`, `document_chunk.py`, `lab_result.py`, `lab_panel.py`, `imaging_report.py`
- servizi: `document_service.py`, `ocr_service.py`, `document_scan_service.py`, `document_rag_service.py`
- mobile: `apps/mobile/lib/features/documents/`

## 3.6. OCR e parsing documentale

Funzioni presenti:

- estrazione testo da PDF digitali con `pypdf`
- OCR immagini/scansioni
- fallback OCR secondario
- retry OCR
- parsing deterministico laboratorio
- parsing deterministico imaging
- revisione manuale post-processing

Stack OCR:

- provider principale: `paddleocr`
- fallback: `tesseract`

Stato:

- pronto a codice
- da validare ancora su casistiche reali difficili

## 3.7. RAG documentale

Funzioni presenti:

- chunking documenti
- embeddings
- rerank
- risposta AI con citazioni
- copertura retrieval mostrata in UI
- ricerca per ambito e documenti selezionati
- retrieval ottimizzato su PostgreSQL

Pipeline RAG:

1. chunking documento
2. full-text search PostgreSQL
3. vector retrieval con `pgvector`
4. rerank
5. answer generation
6. citazioni documento/chunk

Scelte progettuali:

- niente risposta senza base documentale minima
- citazioni e coverage esplicite
- i modelli vedono contesto selezionato, non l'intero archivio raw

## 3.8. Insights AI e recap

Funzioni presenti:

- recap giornaliero
- recap settimanale
- recap mensile
- recap pre-visita
- persistenza dei recap
- rigenerazione recap
- rendering markdown/tabelle migliorato
- schermata AI dedicata nella bottom navigation

Il payload AI include oggi:

- profilo paziente
- condizioni attive
- allergie
- familiarita`
- terapie
- aderenza terapia
- diario e osservazioni
- documenti recenti
- lab e imaging recenti
- alert aperti
- wearable summaries
- sintesi device clinici aggregate
- recap giornalieri precedenti
- motivi di follow-up

Non invia:

- stream grezzi completi dei device
- logica clinica deterministica come testo generato dal modello

Moduli principali:

- backend AI: `summary_provider.py`
- servizio: `insight_service.py`
- mobile: `apps/mobile/lib/features/insights/`

## 3.9. Alert center e red flags

Funzioni presenti:

- motore red flags separato dalla narrativa AI
- alert center
- risoluzione manuale alert
- alert persistenti
- notifiche correlate

Questa parte e` deterministica e spiegabile. Non dipende da LLM.

Moduli principali:

- backend: `alerts.py`
- modelli: `alert.py`
- regole: `apps/backend/app/rules/red_flags.py`
- mobile: `apps/mobile/lib/features/alerts/`

## 3.10. Report

Funzioni presenti:

- report PDF server-side
- report clinici AI
- report stato screening
- ultimo report visualizzabile in app
- download tramite URL firmata

Tipi report principali:

- report AI periodici
- pre-visit report
- screening status report
- export dossier

Moduli principali:

- backend: `reports.py`
- modelli: `report.py`
- mobile: `apps/mobile/lib/features/reports/`

## 3.11. Screening e prevenzione

Funzioni presenti:

- catalogo screening/prevenzione
- eleggibilita` deterministica
- checklist personale annuale
- Centro prevenzione personale
- classificazione `routine`
- classificazione `risk_based`
- classificazione `not_routine`
- classificazione `care_pathway`
- link regionali screening
- availabilities regionali italiane
- follow-up preventivi
- reminder stagionali
- vaccini consigliati

Wave implementate:

- Wave 1:
  - tabacco
  - alcol
  - obesita`
  - counselling lifestyle cardiometabolico
  - vaccini piu` strutturati
- Wave 2:
  - osteoporosi
  - polmone risk-based
  - aneurisma aortico addominale
  - cadute
  - MST personalizzate
- Wave 3:
  - preconcezione / gravidanza
  - registro vaccinale piu` ricco
  - aree `shared_decision`
  - aree `not_routine`

Questa parte e` gestita **deterministicamente**, non da AI generativa.

Moduli principali:

- backend: `screenings.py`, `prevention_center.py`
- servizi: `screening_service.py`, `prevention_center_service.py`
- regole: `apps/backend/app/rules/screenings.py`
- mobile: `apps/mobile/lib/features/screenings/`, `prevention_center/`

## 3.12. Farmaci e aderenza terapeutica

Funzioni presenti:

- farmaci attivi
- schedule farmaci
- conferma assunzione
- storico aderenza
- pausa/ripresa terapia
- rimozione schedule
- giorni specifici
- finestre attive
- cicli on/off
- reminder locali sul device

Scelta architetturale:

- il backend e` source of truth per terapia e preferenze
- i reminder farmaci sono locali al dispositivo

Moduli principali:

- backend: `medications.py`
- modelli: `medication.py`, `medication_schedule.py`, `medication_log.py`
- mobile: `apps/mobile/lib/features/medications/`

## 3.13. Notifiche e inbox

Funzioni presenti:

- inbox notifiche
- preferenze notifiche per categoria
- registrazione token device
- delivery adapter-ready
- canali push/email stub o reali
- alert center separato dalle preferenze

Canali predisposti:

- `log_only`
- webhook
- SMTP
- FCM
- APNs

Stato:

- infrastruttura pronta
- da collegare con credenziali reali per go-live

Moduli principali:

- backend: `notifications.py`
- modelli: `notification.py`, `notification_preference.py`, `notification_device_token.py`
- mobile: `apps/mobile/lib/features/notifications/`

## 3.14. Wearable / smartwatch

Funzioni presenti:

- Health Connect su Android
- Apple Health / HealthKit su iOS
- sync aggregata giornaliera
- diagnostica permessi
- diagnostica sorgenti dati
- debug su metriche mancanti
- uso dei dati wearable nei recap AI

Metriche supportate o parzialmente supportate:

- passi
- distanza
- sonno
- frequenza cardiaca
- frequenza cardiaca a riposo
- SpO2
- calorie attive
- workout/activity
- HRV dove il provider lo espone

Limite importante:

- ClinDiary puo` leggere solo cio` che il provider esporta davvero in Health Connect / HealthKit

Moduli principali:

- backend: `wearables.py`
- modelli: `wearable_daily_summary.py`
- mobile: `apps/mobile/lib/features/wearables/`

## 3.15. Device clinici - Wave 1

Funzioni presenti:

- modulo `Dispositivi`
- catalogo provider
- connessioni profilo-scoped
- import job
- bootstrap connettori
- ingest manuale misure da app
- normalizzazione misure
- uso delle misure in dossier e recap AI

Provider Wave 1 modellati:

- OMRON
- Withings
- iHealth
- A&D Medical
- Dexcom

Stato reale:

- modulo applicativo pronto
- flusso manuale gia` utilizzabile
- live connector completo ancora dipendente da credenziali/approval vendor

Misure manuali supportate:

- pressione
- peso
- SpO2
- temperatura
- frequenza cardiaca
- glicemia BGM

Moduli principali:

- backend: `devices.py`
- modelli: `device_connection.py`, `device_import_job.py`, `device_measurement.py`
- mobile: `apps/mobile/lib/features/devices/`

## 3.16. Dossier salute

Funzioni presenti:

- aggregazione profilo
- allergie, patologie, farmaci, familiarita`
- vaccini
- diario recente
- documenti
- lab
- imaging
- insight e report
- alert
- wearable
- device clinici aggregati
- export PDF
- link di condivisione sicuri
- scheda emergenza
- backup/export JSON
- NFC e condivisione rapida

Il dossier e` pensato come vista unica e ordinata, non come feed grezzo.

Moduli principali:

- backend: `dossier.py`
- modelli: `dossier_share_link.py`
- mobile: `apps/mobile/lib/features/dossier/`

## 3.17. Billing e feature gating

Piani presenti:

- `free`
- `AI Plus`

Free include:

- diario
- timeline
- prevenzione
- storico
- dossier
- reminder farmaci
- documenti locali sul dispositivo

AI Plus include:

- archivio documenti cloud
- OCR
- parsing/reindex cloud
- recap AI
- report AI
- `Chiedi ai documenti`

Gating:

- enforcement lato server
- paywall contestuale lato mobile
- piano demo attivabile in debug

Moduli principali:

- backend: `billing.py`
- modelli: `billing_plan.py`, `billing_feature.py`, `billing_plan_feature.py`, `user_subscription.py`
- mobile: `apps/mobile/lib/features/billing/`

## 3.18. Offline, debug e supporto operativo

Funzioni presenti:

- cache locale Drift
- coda offline
- sync debug screen
- trace rete persistite
- retry e flush locale
- modalita` debug per billing
- smoke CLI backend

Moduli principali:

- mobile: `apps/mobile/lib/features/debug/`
- storage: Drift

## 4. Modelli AI e provider usati

## 4.1. Modello AI principale per recap e report

Provider di default:

- `regolo_ai`

Modello di default:

- `minimax-m2.5`

Uso:

- recap giornalieri
- recap settimanali
- recap mensili
- pre-visit report

Provider alternativi supportati:

- `rule_based`
- `openai_compatible`
- `gemini_ai_studio`

Comportamento:

- fallback sicuro a `rule_based` se il provider esterno fallisce o non e` consentito

## 4.2. Modelli usati per il RAG documentale

Provider:

- Regolo AI

Modelli:

- answer model: `qwen3-8b`
- embedding model: `qwen3-embedding-8b`
- embedding dimensions: `1024` di default
- reranker model: `qwen3-reranker-4b`

Note:

- se il provider non supporta `dimensions`, il sistema ritenta senza parametro
- la dimensione 1024 e` il compromesso scelto tra latenza, spazio e qualita`

## 4.3. Prompting e guardrail

Caratteristiche:

- output in italiano
- tono prudente
- no diagnosi
- no prescrizioni
- uso esclusivo dei dati presenti nel payload
- chiusura con disclaimer
- separazione tra:
  - osservazioni
  - pattern possibili
  - limiti dei dati

## 4.4. AI non usata dove non deve decidere

L'AI non decide:

- red flags
- screening/prevenzione
- eligibility rules
- follow-up deterministici

Queste parti restano nel motore regole.

## 5. Tecnologie usate

## 5.1. Backend

Stack:

- Python 3.12+
- FastAPI
- SQLAlchemy 2
- Alembic
- Celery
- Redis
- PostgreSQL 16
- `pgvector`
- MinIO
- Structlog
- Prometheus-style metrics

Librerie principali:

- `fastapi`
- `sqlalchemy`
- `alembic`
- `celery`
- `redis`
- `psycopg`
- `httpx`
- `minio`
- `pypdf`
- `reportlab`
- `pydantic-settings`
- `PyJWT`

## 5.2. Mobile

Stack:

- Flutter
- Dart
- Riverpod
- GoRouter
- Drift
- Flutter Secure Storage
- Flutter Local Notifications
- Health plugin
- NFC manager

Dipendenze principali:

- `flutter_riverpod`
- `go_router`
- `drift`
- `flutter_secure_storage`
- `flutter_local_notifications`
- `health`
- `table_calendar`
- `share_plus`
- `file_picker`
- `permission_handler`
- `nfc_manager`

## 5.3. OCR e document processing

Stack:

- `pypdf`
- `paddleocr`
- `tesseract` fallback

## 5.4. Infrastruttura locale

Servizi:

- PostgreSQL (`pgvector/pgvector:pg16`)
- Redis
- MinIO
- backend FastAPI
- worker Celery
- beat Celery

## 5.5. Storage

Storage cloud:

- MinIO / S3-compatible

Storage locale:

- vault documenti cifrato lato app
- cache Drift
- token in secure storage

## 6. Architettura software

## 6.1. Backend

Stile:

- modular monolith

Struttura:

- `api/`
- `services/`
- `repositories/`
- `models/`
- `schemas/`
- `rules/`
- `ai/`
- `workers/`

Pattern usati:

- servizi di dominio
- repository per accesso dati
- router per API
- task asincroni per lavori pesanti

## 6.2. Mobile

Stile:

- feature-based organization

Struttura per feature:

- `data`
- `domain`
- `presentation`

Pattern usati:

- Riverpod per state management
- GoRouter per navigation
- Drift per offline/local persistence

## 7. Sicurezza, audit e compliance tecnica

Funzioni presenti:

- refresh token rotation
- audit trail persistente
- request id e tracing HTTP
- rate limiting auth
- validazione MIME reale documenti
- hash SHA-256 documenti
- hook scan documenti
- viewer URL firmate
- hidden docs/openapi in produzione
- vault locale documenti cifrato AES-GCM
- retention schedulata
- note legali beta in app
- export/cancellazione account

Documentazione dedicata:

- `docs/legal/`
- `docs/architecture/pre-production-gdpr-ai.md`
- `docs/architecture/privacy-ai-notice-draft.md`

## 8. UX e stato del mobile

Principi attuali:

- UI semplificata e piu` minimale
- tab dedicate per schermate lunghe
- bottom navigation floating minimal con tab AI centrale
- dialoghi long-form scrollabili
- rendering markdown/tabelle migliorato
- maggiore leggibilita` per dossier, report e prevenzione

Schermate principali:

- Home
- Diario
- AI
- Documenti
- Profilo
- Storico
- Timeline
- Report
- Prevenzione
- Dossier
- Dispositivi
- Wearable
- Impostazioni

## 9. Tooling e script

Script rilevanti:

- `scripts/run_android_app.sh`
- `scripts/run_android_app.ps1`

CLI backend:

- `clindiary-api`
- `clindiary-seed`
- `clindiary-worker`
- `clindiary-beat`
- `clindiary-ocr-smoke`
- `clindiary-ai-smoke`
- `clindiary-ai-eval`
- `clindiary-notification-smoke`
- `clindiary-notification-audit`
- `clindiary-screening-links-audit`

## 10. Stato reale di maturita`

## Gia` maturo a codice

- core mobile/backend
- AI recap
- RAG documentale
- prevenzione deterministica
- farmaci e reminder locali
- dossier salute
- feature gating AI Plus
- wearable hub integration
- device module Wave 1 baseline

## Pronto ma non ancora validato completamente in produzione reale

- OCR su scansioni difficili reali
- notifiche push/email con credenziali vere
- live connectors vendor per device clinici
- validazione estesa wearable su OEM Android
- governance GDPR/MDR completa per go-live

## 11. Gap ancora aperti

Gap principali ancora aperti:

1. validazione clinica/qualitativa dei prompt AI su casi reali
2. OCR e scan su documenti difficili reali
3. credenziali reali FCM/APNs/SMTP
4. manutenzione continua dei link screening regionali
5. offline-first piu` ricco
6. copertura test ancora piu` profonda
7. completamento governance privacy/GDPR/AI
8. live onboarding vendor per device Wave 1

## 12. Sintesi finale

ClinDiary oggi e` gia` una piattaforma molto piu` ampia di un semplice diario sintomi. Le aree gia` implementate e collegate tra loro sono:

- diario clinico
- documenti sanitari
- AI prudente
- report
- prevenzione
- farmaci
- notifiche
- wearable
- device clinici
- dossier salute
- billing AI Plus

L'AI attuale usa:

- `minimax-m2.5` per recap/report via Regolo
- `qwen3-8b` per answer RAG
- `qwen3-embedding-8b` per embeddings
- `qwen3-reranker-4b` per rerank

Le tecnologie principali sono:

- FastAPI
- Celery
- PostgreSQL + pgvector
- Redis
- MinIO
- Flutter
- Riverpod
- Drift

Lo stato complessivo del progetto e`:

- **molto avanzato a livello di prodotto e codice**
- **non ancora completamente chiuso come go-live istituzionale/clinico**

Questo significa che il progetto oggi e` forte come:

- prototipo avanzato
- beta quasi production-oriented
- base credibile per pilot, demo, partner e iterazioni finali

ma richiede ancora:

- validazioni reali
- credenziali/live integrations
- chiusura compliance formale

prima di essere presentato come prodotto pronto per un roll-out istituzionale completo.
