# ClinDiary — Guida Rigorosa alla Struttura del Progetto

Questa guida ti dice:

- come e organizzata la repo
- che cosa contiene ogni cartella
- che cosa fa ogni file importante
- dove devi intervenire quando vuoi cambiare un modulo
- quali file sono sorgente reale e quali sono solo supporto o generati

## 1. Regola fondamentale di lettura

ClinDiary e un monorepo con due applicazioni principali:

- `apps/backend`: API FastAPI, worker Celery, business logic, regole cliniche, persistence
- `apps/mobile`: app Flutter, UI, repository client, cache locale, navigazione

Il progetto separa in modo esplicito:

- business logic: `services/`
- regole cliniche: `rules/`
- AI logic: `ai/`
- persistence/data access: `models/` + `repositories/`
- REST contract: `schemas/` + `api/`
- UI logic: `apps/mobile/lib/features/**/presentation`

## 2. Cosa NON e sorgente da modificare normalmente

Non lavorare, salvo casi speciali, dentro:

- `.git/`
- `__pycache__/`
- `.venv/`
- `.pytest_cache/`
- `.dart_tool/`
- `build/`
- file `ephemeral`
- file generati come `GeneratedPluginRegistrant.*`

Questi non sono il cuore applicativo.

## 3. Root della repository

### `/.gitignore`

Serve a ignorare virtualenv, cache Python, build Flutter, storage locale e file temporanei.

### `/ClinDiary Bue Print.md`

E il blueprint originale. E la sorgente di verita del progetto.

### `/Makefile`

Contiene shortcut di sviluppo:

- `backend-install`
- `backend-test`
- `backend-run`
- `backend-seed`
- `worker-run`
- `beat-run`
- `mobile-get`
- `mobile-analyze`
- `mobile-test`
- `stack-up`
- `stack-down`
- `android-run`

### `/scripts/`

Script operativi locali.

#### `/scripts/run_android_app.sh`

Runner one-command per Android:

- avvia servizi docker locali
- prepara il backend se manca il virtualenv
- esegue migration e seed
- avvia `uvicorn`, `celery worker`, `celery beat`
- rileva il device Android
- configura `adb reverse` o fallback rete
- lancia `flutter run` con `API_BASE_URL` corretto

### `/README.md`

Documentazione generale del monorepo:

- stato del progetto
- avvio locale
- seed demo
- test
- note implementative

## 4. Cartella `apps/`

Contiene le due applicazioni vere.

---

## 5. `apps/backend/`

Questa e l’app server.

### File top-level backend

#### `apps/backend/.env.example`

Template delle variabili ambiente:

- DB
- Redis
- JWT
- MinIO
- AI provider
- Celery
- sync notifiche

#### `apps/backend/Dockerfile`

Build container del backend/worker/beat.

#### `apps/backend/README.md`

README locale del backend, aggiornato allo stato reale corrente del server.

#### `apps/backend/alembic.ini`

Config Alembic per migrazioni DB.

#### `apps/backend/pyproject.toml`

Manifest Python:

- dipendenze runtime
- dipendenze dev
- entrypoint CLI
- config pytest

### `apps/backend/alembic/`

Gestisce le migrazioni DB.

#### `apps/backend/alembic/env.py`

Bootstrap Alembic.

#### `apps/backend/alembic/versions/20260320_0001_phase1_baseline.py`

Schema iniziale Phase 1:

- utenti
- profili
- diario
- sintomi
- parametri
- timeline base

#### `apps/backend/alembic/versions/20260320_0002_documents_phase2.py`

Schema documentale Phase 2:

- documenti
- parsing lab/imaging

#### `apps/backend/alembic/versions/20260320_0003_phase3_insights_alerts_reports.py`

Schema Phase 3:

- `ai_summaries`
- `alerts`
- `reports`

#### `apps/backend/alembic/versions/20260320_0004_phase4_screenings_medications_notifications.py`

Schema Phase 4:

- screenings
- medication schedules/logs
- notifications

#### `apps/backend/alembic/versions/20260320_0005_notification_preferences.py`

Aggiunge le preferenze notifiche utente.

#### `apps/backend/alembic/versions/20260321_0006_phase5_foundations.py`

Schema hardening / notifiche evolute:

- device token
- delivery adapters
- schedule farmaci avanzati

#### `apps/backend/alembic/versions/20260321_0007_monthly_insights_history.py`

Aggiunge:

- insight mensili persistite
- base storico giornaliero con recap periodici

#### `apps/backend/alembic/versions/20260321_0008_wearables_daily_summaries.py`

Aggiunge:

- `wearable_daily_summaries`
- storage giornaliero aggregato per dati smartwatch / telefono

#### `apps/backend/alembic/versions/20260321_0009_security_audit_metrics.py`

Aggiunge:

- `audit_logs`
- metadata provider/model per `ai_summaries`
- hardening documenti (`content_sha256`, validazione firma, scan status)

#### `apps/backend/alembic/versions/20260324_0013_prevention_catalog_fields.py`

Aggiunge:

- metadati del catalogo prevenzione (`recommendation_level`, `cadence_label`, `catalog_only`)

#### `apps/backend/alembic/versions/20260331_0026_billing_entitlements.py`

Introduce il baseline billing:

- `billing_features`
- `billing_plans`
- `billing_plan_features`
- `user_subscriptions`
- enum per intervalli e stato subscription
- capability `cloud_document_storage` per distinguere archivio locale free da archivio cloud AI Plus
- supporto BMI nelle regole screening

#### `apps/backend/alembic/versions/20260324_0014_screening_completion_records.py`

Aggiunge:

- `screening_completion_records`
- storico dei completamenti annuali per checklist personale prevenzione

#### `apps/backend/alembic/versions/20260331_0022_document_folders.py`

Aggiunge:

- `document_folders`
- supporto archivio a cartelle annidate per i documenti clinici

#### `apps/backend/alembic/versions/20260331_0023_document_rag_chunks.py`

Aggiunge:

- `document_chunks`
- supporto indicizzazione RAG dei documenti
- colonna embedding compatibile con `pgvector`

#### `apps/backend/alembic/versions/20260331_0024_document_rag_search_indexes.py`

Aggiunge:

- indice GIN full-text sui chunk documentali
- indice composito di supporto per le query di retrieval su PostgreSQL

#### `apps/backend/alembic/versions/20260331_0025_document_chunk_embedding_dimensions.py`

Aggiunge:

- `embedding_dimensions` su `document_chunks`
- supporto sicuro a reindex futuri con dimensioni embedding diverse

### `apps/backend/app/`

E il package Python principale.

#### `apps/backend/app/__init__.py`

Marker package.

#### `apps/backend/app/main.py`

Entrypoint FastAPI:

- crea l’app
- configura logging
- monta CORS
- include il router v1
- espone `/health`
- espone `/metrics`

#### `apps/backend/app/ai/document_rag_provider.py`

Adapter AI dedicato alla query sui documenti:

- embeddings
- rerank
- answer generation con citazioni
- fallback rule-based prudente

Usa Regolo per:

- `qwen3-embedding-8b`
- `qwen3-reranker-4b`
- `qwen3-8b`

Supporta anche:

- `DOCUMENT_EMBEDDING_DIMENSIONS` configurabile
- retry automatico senza `dimensions` se il provider embeddings non accetta il parametro

#### `apps/backend/app/seed.py`

Seed demo applicativo:

- utente demo
- profilo
- diario iniziale
- documento demo
- farmaco demo
- screening catalog/status
- notifiche demo

#### `apps/backend/app/models/document_folder.py`

Modello SQLAlchemy della cartella documentale.

Serve per:

- cartelle annidate
- breadcrumb archivio
- move file
- query per cartella

#### `apps/backend/app/models/document_chunk.py`

Indice documentale chunkato per il modulo RAG.

Contiene:

- riferimento al paziente
- riferimento al documento
- cartella
- testo chunkato
- metadata documento
- dimensione embedding effettiva
- embedding

#### `apps/backend/app/models/vector_type.py`

Tipo SQLAlchemy custom che usa:

- `vector` su PostgreSQL
- JSON fallback altrove

Serve per non legare i test a una dipendenza Python pgvector specifica.

#### `apps/backend/app/services/document_rag_service.py`

Service del retrieval documentale.

Responsabilita:

- reindex singolo documento
- reindex archivio paziente
- costruzione chunk da metadata/OCR/lab/imaging
- scoring iniziale
- retrieval SQL ottimizzato su PostgreSQL con fallback Python
- rerank
- answer finale con citazioni deterministicamente agganciate ai chunk

#### `apps/backend/app/api/v1/documents.py`

Oltre agli endpoint documentali classici, ora espone anche:

- query documentale `POST /documents/query`
- reindex archivio `POST /documents/reindex`
- reindex singolo documento `POST /documents/{id}/reindex`

#### `apps/backend/app/workers/document_tasks.py`

Task Celery documentali.

Ora include anche:

- processing documento
- reindex documento
- reindex documenti paziente

#### `apps/backend/app/models/device_connection.py`

Connessione tra profilo ClinDiary e provider/device esterno.

Contiene:

- provider code e nome leggibile
- tipo integrazione (`cloud_api`, `partner_platform`, `api_key`, `sdk_bridge`)
- stato connessione
- token/API key e metadata provider
- ultimo sync e ultimo errore

#### `apps/backend/app/models/device_measurement.py`

Misura normalizzata importata da un device/app salute.

Contiene:

- riferimento al profilo e al connettore
- tipo metrica (`blood_pressure`, `spo2`, `body_weight`, ecc.)
- valori primari/secondari/terziari
- timestamp misura
- provenance vendor/device

#### `apps/backend/app/models/device_import_job.py`

Storico delle importazioni device.

Contiene:

- connettore associato
- provider
- stato job
- conteggio elementi importati
- summary ed errore

### `apps/backend/app/ai/`

Contiene la logica AI, separata dalle regole cliniche.

#### `apps/backend/app/ai/__init__.py`

Marker package.

#### `apps/backend/app/ai/summary_provider.py`

Provider della narrativa prudente.

Responsabilita:

- costruire testo AI/non diagnostico
- restare separato da red flags
- gestire provider `rule_based`, `openai_compatible`, `gemini_ai_studio`
- restituire anche metadata di esecuzione (`provider_name`, `model_name`)

### `apps/backend/app/api/`

Espone l’API REST.

#### `apps/backend/app/api/__init__.py`

Marker package.

#### `apps/backend/app/api/deps.py`

Dependency FastAPI:

- autenticazione Bearer
- recupero utente corrente
- ownership base

### `apps/backend/app/api/v1/`

Qui vivono le route v1.

Nota pratica:

- ogni file route espone solo HTTP contract
- l’orchestrazione vera sta nei `services/`
- se devi aggiungere una feature, evita di mettere logica direttamente nelle route

#### `alerts.py`

Endpoint alert:

- list
- resolve

#### `auth.py`

Endpoint auth:

- register
- login
- refresh
- logout
- password reset

#### `daily_entries.py`

Endpoint diario:

- create
- list
- detail
- update

#### `documents.py`

Endpoint documenti:

- upload
- list
- detail
- process
- review manuale
- content viewer

#### `devices.py`

Endpoint dispositivi/app salute:

- overview provider + connessioni
- link/update connettori
- sync connection
- ingest misure dal client/bridge SDK

#### `billing.py`

Endpoint piani/entitlements:

- `GET /billing/plans`
- `GET /billing/me`
- `POST /billing/dev/activate`
- `POST /billing/dev/cancel`

#### `insights.py`

Endpoint insights:

- daily
- weekly
- monthly
- pre-visit

#### `history.py`

Endpoint storico giornaliero:

- dettaglio giornata per data
- check-in del giorno
- recap AI giornaliero
- recap settimanale/mensile opzionali nello stesso payload
- dati wearable del giorno
- documenti del giorno
- eventi timeline del giorno

#### `medications.py`

Endpoint aderenza farmaci:

- logs
- log di una dose

#### `notifications.py`

Endpoint inbox notifiche:

- list
- mark read
- get preferences
- update preferences

#### `prevention_center.py`

Endpoint aggregato del Centro prevenzione personale:

- overview personale prevenzione
- visita annuale consigliata
- controlli per eta/sesso
- vaccini consigliati da verificare
- controlli stagionali
- follow-up aperti

#### `wearables.py`

Endpoint wearable/smartwatch:

- sync giornaliera aggregata da app mobile
- list degli ultimi riassunti sincronizzati

#### `profile.py`

Endpoint profilo:

- profile me
- update
- onboarding complete
- allergies
- conditions
- medications
- family history

#### `reports.py`

Endpoint report:

- generate
- detail
- content PDF

#### `dossier.py`

Endpoint aggregato del Dossier salute:

- profilo clinico ordinato
- diario recente
- documenti/referti recenti
- lab/imaging strutturati
- insight, report, alert e wearable

#### `router.py`

Router aggregatore di tutte le route v1.

#### `screenings.py`

Endpoint screening:

- catalog
- me
- recompute
- mark-done

#### `symptoms.py`

Endpoint per aggiungere sintomi a un daily entry.

#### `timeline.py`

Endpoint timeline aggregata.

#### `vitals.py`

Endpoint per aggiungere parametri a un daily entry.

### `apps/backend/app/core/`

Contiene il nucleo tecnico condiviso.

#### `config.py`

Settings centralizzati via environment.

#### `database.py`

Engine SQLAlchemy, session factory, dependency DB.

#### `exceptions.py`

Eccezioni tecniche/comuni.

#### `logging.py`

Config logging backend.

#### `security.py`

Sicurezza applicativa:

- password hash
- JWT
- token vari

#### `http_middleware.py`

Middleware HTTP centrale:

- `X-Request-ID`
- `X-Response-Time-Ms`
- rate limit auth
- logging request/response
- utility date/time

#### `storage.py`

Astrazione storage file:

- MinIO
- fallback locale

### `apps/backend/app/models/`

Qui ci sono i model SQLAlchemy, cioe lo schema applicativo del dominio.

#### File base

- `__init__.py`: aggrega/exporta i model
- `base.py`: `Base`, mixin timestamp, UUID PK
- `enums.py`: enum condivisi dell’intero dominio

#### Identity e profilo

- `user.py`: account utente
- `user_onboarding.py`: stato onboarding e consenso sanitario
- `refresh_token.py`: refresh token persistiti
- `password_reset_token.py`: token reset password
- `patient_profile.py`: profilo clinico principale

#### Profilo clinico

- `allergy.py`: allergie
- `medical_condition.py`: patologie/condizioni note
- `family_history.py`: familiarita
- `medication.py`: farmaco definito nel profilo
- `medication_schedule.py`: orari/schedule farmaco
- `medication_log.py`: storico aderenza farmaco

#### Diario clinico

- `daily_entry.py`: check-in giornaliero
- `symptom_entry.py`: sintomi legati a un daily entry
- `vital_sign_entry.py`: parametri/vitali legati a un daily entry
- `wearable_daily_summary.py`: riassunto giornaliero aggregato dei dati smartwatch/telefono sincronizzati dall’app

#### Timeline

- `timeline_event.py`: evento normalizzato della timeline

#### Documenti

- `clinical_document.py`: metadato documento clinico, con cartella opzionale di appartenenza
- `document_folder.py`: cartella annidata dell'archivio documentale personale
- `lab_panel.py`: pannello lab strutturato
- `lab_result.py`: singolo risultato lab
- `imaging_report.py`: referto imaging strutturato

#### AI / alert / report

- `ai_summary.py`: sintesi persistita
- `alert.py`: alert clinico spiegabile
- `report.py`: report clinico generato

#### Screening / prevenzione / notifiche

- `screening_program.py`: catalogo prevenzione/screening; contiene metadati come categoria, livello raccomandazione (`routine`, `risk_based`, `not_routine`), cadenza leggibile e flag `catalog_only`
- `screening_rule.py`: criteri deterministici screening; oggi supporta eta, sesso biologico, fumo, keyword di familiarita e soglia minima BMI
- `patient_screening_status.py`: stato screening del paziente
- `screening_completion_record.py`: log dei completamenti screening/prevenzione; serve per la checklist annuale spuntabile senza perdere lo storico
- `regional_screening_availability.py`: disponibilita regionale/pubblica
- `notification.py`: notifica inbox
- `notification_device_token.py`: token device per delivery push futuro
- `notification_preference.py`: preferenze notifiche del paziente
- `screening_notification.py`: legame reminder screening -> notifica

### `apps/backend/app/repositories/`

Qui c’e il data access. I repository leggono/scrivono i model ma non orchestrano il flusso clinico.

#### File

- `__init__.py`: marker
- `user_repository.py`: utenti, login helpers, refresh/reset tokens
- `profile_repository.py`: profilo e risorse del profilo
- `daily_entry_repository.py`: diario, sintomi, parametri
- `timeline_repository.py`: timeline events
- `document_repository.py`: documenti, cartelle archivio, ricerca documentale e strutturato lab/imaging
- `insight_repository.py`: lettura/scrittura `ai_summaries`
- `alert_repository.py`: alert clinici
- `report_repository.py`: report generati
- `screening_repository.py`: catalogo, status e reminder screening
- `screening_repository.py`: catalogo, status, reminder screening e log dei completamenti annuali
- `medication_repository.py`: therapy schedules e logs
- `notification_repository.py`: inbox notifiche
- `notification_preference_repository.py`: preferenze notifiche
- `wearable_repository.py`: lettura/scrittura riassunti wearable giornalieri

### `apps/backend/app/rules/`

Qui vanno solo regole cliniche deterministiche.

#### File

- `__init__.py`: marker
- `red_flags.py`: regole di attenzione/urgenza
- `screenings.py`: eleggibilita screening e prevenzione personale, con regole spiegabili e senza diagnosi automatiche

Se una regola ha implicazioni cliniche, questo e il posto giusto.

### `apps/backend/app/schemas/`

Qui stanno DTO e contract API.

#### File

- `__init__.py`: marker
- `auth.py`: request/response auth
- `profile.py`: DTO profilo, onboarding, allergy/condition/medication/family history
- `daily_entries.py`: DTO diario, sintomi, parametri
- `documents.py`: DTO documenti, cartelle archivio, move-file e risposta archivio con breadcrumb
- `dossier.py`: DTO aggregato del dossier salute
- `insights.py`: DTO insight
- `alerts.py`: DTO alert
- `prevention_center.py`: DTO aggregato del Centro prevenzione personale
- `reports.py`: DTO report
- `screenings.py`: DTO screening
- `screenings.py`: DTO screening; include anche il campo derivato `care_pathway` per distinguere visita annuale, controlli da discutere e voci non routinarie
- `medications.py`: DTO aderenza farmaci
- `notifications.py`: DTO inbox e preferenze notifiche
- `history.py`: DTO aggregato giorno
- `timeline.py`: DTO timeline
- `wearables.py`: DTO sync/list dei riassunti wearable giornalieri
- `common.py`: tipi condivisi minori

### `apps/backend/app/services/`

Qui c’e la business logic vera. I service coordinano repository, rules, storage, timeline e commit.

#### File

- `__init__.py`: marker
- `auth_service.py`: registrazione, login, refresh, logout, reset
- `profile_service.py`: onboarding e gestione profilo clinico
- `daily_entry_service.py`: journaling, sintomi, parametri, timeline, trigger alert
- `timeline_service.py`: lettura timeline aggregata
- `document_service.py`: upload, processing, parsing, viewer
- `document_classifier.py`: classificazione deterministica documento
- `document_parser.py`: parsing deterministico lab/imaging
- `insight_service.py`: crea sintesi prudenti usando profilo, diario, farmaci, documenti recenti, lab/imaging e alert; espone daily/weekly/monthly/pre-visit e sync schedulato
- `billing_service.py`: seed catalogo piani, risoluzione entitlements, attivazione demo subscription e gating delle capability AI
- `history_service.py`: compone la vista giornata per lo storico consultabile da calendario
- `alert_service.py`: sincronizza alert e resolve
- `report_pdf_builder.py`: costruzione PDF
- `report_service.py`: genera, salva, espone report
- `screening_service.py`: seed/upsert del catalogo prevenzione, recompute personalizzato, mark-done, undo del completamento annuale, timeline screening e classificazione `care_pathway`
- `prevention_center_service.py`: aggrega screening, vaccini, controlli stagionali e follow-up in una vista unica per il paziente
- `dossier_service.py`: costruisce la cartella clinica personale pronta all'uso aggregando profilo, diario, documenti, insight, report, alert e wearable
- `medication_adherence_service.py`: registra assunzioni e storico
- `notification_service.py`: inbox, preferenze, deduplica, sync reminder
- `notification_delivery_service.py`: adapter delivery `log_only/webhook/smtp`
- `ocr_service.py`: adapter OCR reale/stub e smoke helper
- `wearable_service.py`: upsert/list dei riassunti wearable sincronizzati dal mobile

### `apps/backend/app/workers/`

Worker Celery e task asincroni.

#### File

- `__init__.py`: marker
- `celery_app.py`: configurazione Celery e beat schedule
- `document_tasks.py`: task processing documenti
- `notification_tasks.py`: sync periodico notifiche
- `summary_tasks.py`: generazione automatica recap daily/weekly/monthly

### `apps/backend/tests/`

Test backend.

#### File

- `conftest.py`: test app, DB sqlite, fixture auth
- `test_auth_api.py`: auth
- `test_profile_api.py`: profilo
- `test_daily_entries_api.py`: diario, sintomi, parametri
- `test_documents_api.py`: documenti
- `test_document_parser.py`: parser documenti
- `test_billing_api.py`: catalogo piani, feature lock, downgrade pulito dello storico e attivazione demo AI Plus
- `test_phase3_api.py`: insight, alert, report
- `test_red_flags_rule_engine.py`: regole cliniche Phase 3
- `test_phase4_api.py`: screening, aderenza, notifiche, preferenze
- `test_prevention_center_and_dossier_api.py`: endpoint aggregati Centro prevenzione personale e Dossier salute
- `test_wearables_api.py`: sync wearable, storico e recap con contesto smartwatch

---

## 6. `apps/mobile/`

Questa e l’app Flutter.

### File top-level mobile

#### `apps/mobile/pubspec.yaml`

Manifest Flutter/Dart: dipendenze e assets.

#### `apps/mobile/pubspec.lock`

Lockfile delle dipendenze. Va versionato.

#### `apps/mobile/analysis_options.yaml`

Regole di analisi statica Dart/Flutter.

#### `apps/mobile/README.md`

README del mobile, aggiornato allo stato reale corrente dell’app.

#### `apps/mobile/.gitignore`

Ignore interno Flutter.

#### `apps/mobile/.metadata`

Metadata Flutter del progetto.

### `apps/mobile/lib/`

Sorgente applicativo Flutter.

#### Entrypoint

- `main.dart`: inizializza locale `it_IT`, Riverpod, app root

### `apps/mobile/lib/app/`

Wiring globale app.

#### File

- `app.dart`: `MaterialApp.router`
- `bootstrap/medication_reminder_bootstrap.dart`: inizializza e sincronizza i reminder farmaci locali quando cambiano sessione, profilo o preferenze notifiche
- `bootstrap/wearable_sync_bootstrap.dart`: tenta la sync wearable in background all’avvio solo se sessione, provider salute e permessi sono gia disponibili
- `router.dart`: GoRouter e shell con tab principali
- `dependencies.dart`: dependency injection dei repository/client/storage
- `providers.dart`: provider Riverpod globali

### `apps/mobile/lib/app/core/`

Nucleo tecnico mobile.

#### File

- `app_config.dart`: base URL e config app
- `network/api_client.dart`: HTTP client, refresh token automatico, multipart
- `notifications/local_medication_reminder_service.dart`: scheduling locale reminder terapia su device con `flutter_local_notifications` + `timezone`, senza backend
- `storage/local_database.dart`: cache locale Drift
- `storage/local_database.g.dart`: file generato Drift
- `storage/secure_token_storage.dart`: persistenza token sicura

### `apps/mobile/lib/app/theme/`

- `app_theme.dart`: tema grafico globale

### `apps/mobile/lib/features/`

Organizzazione feature-first. Ogni feature segue il pattern:

- `data/`: repository client
- `domain/`: model lato mobile
- `presentation/`: schermate e componenti UI

#### `features/auth/`

- `data/auth_repository.dart`: chiama API auth
- `domain/auth_session.dart`: sessione utente mobile
- `presentation/auth_controller.dart`: controller Riverpod auth
- `presentation/login_screen.dart`: login
- `presentation/register_screen.dart`: registrazione
- `presentation/session_gate_screen.dart`: decide se andare a auth/onboarding/app

#### `features/onboarding/`

- `presentation/onboarding_screen.dart`: completamento profilo iniziale e consenso

#### `features/billing/`

- `data/billing_repository.dart`: API piani, stato subscription e attivazione demo
- `domain/billing_status.dart`: model mobile per piano corrente, catalogo e feature sbloccate
- `presentation/billing_screen.dart`: paywall/piani AI Plus con CTA debug per attivare il gating lato backend

#### `features/profile/`

- `data/profile_repository.dart`: API profilo
- `domain/profile_bundle.dart`: model mobile profilo+allergie+condizioni+farmaci+familiarita
- `presentation/profile_screen.dart`: schermata profilo clinico; include creazione farmaci con `TimePicker`, selezione giorni e trigger sync reminder locali

#### `features/daily_journal/`

- `data/daily_journal_repository.dart`: API diario
- `domain/daily_entry.dart`: model mobile diario/sintomi/vitali
- `presentation/diary_screen.dart`: overview diario
- `presentation/daily_check_in_screen.dart`: check-in rapido
- `presentation/symptom_entry_screen.dart`: dettaglio sintomo

#### `features/timeline/`

- `data/timeline_repository.dart`: API timeline
- `domain/timeline_event.dart`: model evento timeline
- `presentation/timeline_screen.dart`: timeline aggregata

#### `features/documents/`

- `data/document_picker_service.dart`: picker file locale
- `data/local_document_vault_service.dart`: vault documentale locale su dispositivo per il piano free, con cartelle, ricerca metadata-only e move-file
- `data/documents_repository.dart`: repository ibrido che sceglie tra vault locale free e archivio cloud AI Plus
- `domain/clinical_document.dart`: model mobile documenti, cartelle e vista archivio
- `domain/document_manual_review.dart`: payload tipizzati per revisione manuale
- `presentation/documents_screen.dart`: archivio documentale a cartelle con breadcrumb, ricerca, upload/salvataggio nella cartella corrente e CTA di upgrade quando serve il cloud
- `presentation/document_upload_screen.dart`: salvataggio locale o upload cloud in base al piano, con cartella di destinazione opzionale
- `presentation/document_detail_screen.dart`: dettaglio documento con move-file, viewer locale/cloud e visualizzazione OCR on-demand quando disponibile
- `presentation/document_query_screen.dart`: query documentale con citazioni apribili, scope per cartella e trigger manuale di reindex
- `presentation/document_review_screen.dart`: conferma/correzione manuale di metadata e parsing
- `presentation/document_ui.dart`: helper UI documentale

#### `features/devices/`

- `data/devices_repository.dart`: API del modulo device Wave 1
- `domain/device_hub.dart`: model mobile per provider, connessioni, misure e import job
- `presentation/devices_screen.dart`: schermata `Dispositivi` con setup provider, overview connessioni, misure recenti e storico import

#### `features/insights/`

- `data/insights_repository.dart`: API insights
- `domain/insight_summary.dart`: model sintesi e query con data di riferimento
- `presentation/insights_screen.dart`: visualizzazione insight daily/weekly/monthly/pre-visit con selezione data e paywall contestuale se la capability AI e` bloccata

#### `features/prevention_center/`

- `data/prevention_center_repository.dart`: API del Centro prevenzione personale
- `domain/prevention_center.dart`: model mobile overview, raccomandazioni e follow-up
- `presentation/prevention_center_screen.dart`: schermata aggregata con visita annuale, controlli per profilo, vaccini, stagionalita e follow-up

#### `features/history/`

- `data/history_repository.dart`: API storico giornaliero
- `domain/history_day.dart`: aggregato giorno con check-in, recap, documenti, wearable ed eventi
- `presentation/history_screen.dart`: calendario e dettaglio della giornata, inclusi i dati wearable del giorno

#### `features/alerts/`

- `data/alerts_repository.dart`: API alert
- `domain/clinical_alert.dart`: model alert
- `presentation/alert_ui.dart`: mapping colore/icone/severita
- `presentation/alerts_screen.dart`: alert center

#### `features/reports/`

- `data/reports_repository.dart`: API report
- `domain/clinical_report.dart`: model report
- `presentation/reports_screen.dart`: genera/apre report; i report AI mostrano CTA upgrade se il piano non include l'entitlement

#### `features/dossier/`

- `data/dossier_repository.dart`: API del Dossier salute
- `domain/health_dossier.dart`: model mobile della cartella clinica personale aggregata
- `presentation/health_dossier_screen.dart`: schermata dossier con sezioni ordinate per profilo, diario, referti, insight, report, alert, wearable e dispositivi clinici

#### `features/screenings/`

- `data/screenings_repository.dart`: API screening
- `domain/screening.dart`: model catalog/status/availability; include livello raccomandazione, cadenza, flag `catalogOnly` e `carePathway`
- `presentation/screenings_screen.dart`: schermata prevenzione con sezioni per profilo utente, checklist personale dell'anno corrente, visita annuale consigliata, esami da discutere col medico e pratiche non di routine

#### `features/medications/`

- `data/medications_repository.dart`: API aderenza farmaci
- `domain/medication_adherence.dart`: model log terapia
- `presentation/medications_screen.dart`: terapia attiva e storico aderenza; al log della dose cancella il reminder locale del giorno per quel farmaco

#### `features/notifications/`

- `data/notifications_repository.dart`: API inbox e preferenze notifiche
- `domain/app_notification.dart`: model notifiche e preferenze
- `presentation/notifications_screen.dart`: inbox + toggle preferenze + stato/sync reminder locali farmaci e richiesta permessi OS

#### `features/home/`

- `presentation/home_screen.dart`: dashboard, quick actions, riepiloghi, accesso rapido a storico, Centro prevenzione, Dossier salute, insights, smartwatch, moduli clinici e schermata AI Plus

#### `features/wearables/`

- `data/wearable_health_service*.dart`: adapter platform-aware verso Health Connect / Apple Health, richiesta permessi, install provider Android, raccolta dati e aggregazione giornaliera
- `data/wearables_repository.dart`: API sync/list dei riassunti wearable backend
- `domain/wearable_day_summary.dart`: model mobile del riepilogo giornaliero aggregato
- `domain/wearable_sync.dart`: stato connessione, risultato sync ed errori wearable
- `presentation/wearables_screen.dart`: UI di connessione, permessi, sync manuale e lista ultimi giorni sincronizzati

### `apps/mobile/lib/shared/widgets/`

Widget condivisi.

#### File

- `async_view.dart`: helper UI async
- `metric_slider.dart`: slider metrica check-in
- `root_shell.dart`: shell tab principali
- `section_card.dart`: card/sezione riutilizzabile
- `feature_lock_card.dart`: blocco riusabile per mostrare upgrade/paywall contestuale delle sole feature AI

### `apps/mobile/test/`

Test mobile.

#### File

- `auth/auth_controller_provider_test.dart`: auth provider
- `auth/login_screen_test.dart`: login UI
- `core/local_database_test.dart`: cache locale
- `documents/documents_flow_test.dart`: flussi documenti
- `notifications/local_medication_reminder_service_test.dart`: planner reminder locali farmaci
- `timeline/timeline_screen_test.dart`: timeline UI
- `phase3/phase3_screens_test.dart`: insight/alert/report
- `phase4/phase4_screens_test.dart`: screening/medications/notifications
- `home/prevention_dossier_screens_test.dart`: UI Centro prevenzione e Dossier salute
- `wearables/wearables_screen_test.dart`: UI wearable/smartwatch
- `support/fakes.dart`: fake/shared helpers test

### `apps/mobile/android/`

Bootstrap Android Flutter.

File principali:

- `.gitignore`: ignore Android locale
- `app/build.gradle.kts`: config modulo app Android; `minSdk = 26` per compatibilita con plugin `health`
- `build.gradle.kts`: config build Android root
- `gradle.properties`: proprietà Gradle
- `gradle/wrapper/gradle-wrapper.jar`: wrapper binario
- `gradle/wrapper/gradle-wrapper.properties`: config wrapper
- `app/src/main/AndroidManifest.xml`: permessi Health Connect, `ACTIVITY_RECOGNITION`, intent rationale, alias privacy usage, boot receivers reminder locali
- `gradlew`, `gradlew.bat`: launcher Gradle
- `settings.gradle.kts`: settings build
- `app/src/main/AndroidManifest.xml`: manifest Android
- `app/src/main/res/...`: launcher/background resources

File locali da non versionare:

- `local.properties`

### `apps/mobile/ios/`

Bootstrap iOS Flutter.

File principali:

- `.gitignore`
- `Flutter/AppFrameworkInfo.plist`
- `Flutter/Debug.xcconfig`
- `Flutter/Release.xcconfig`
- `Runner.xcodeproj/project.pbxproj`
- `Runner.xcworkspace/...`
- `Runner/AppDelegate.swift`
- `Runner/Base.lproj/LaunchScreen.storyboard`
- `Runner/Base.lproj/Main.storyboard`
- `Runner/Info.plist`: descrizioni permessi Apple Health
- `Runner/Runner.entitlements`: capability HealthKit
- `Runner/Runner-Bridging-Header.h`
- `RunnerTests/RunnerTests.swift`

File generati/di supporto da non toccare di norma:

- `Flutter/Generated.xcconfig`
- `Flutter/ephemeral/*`
- `Flutter/flutter_export_environment.sh`
- `Runner/GeneratedPluginRegistrant.*`

### `apps/mobile/linux/`

Bootstrap desktop Linux.

File principali:

- `.gitignore`
- `CMakeLists.txt`
- `flutter/CMakeLists.txt`
- `runner/CMakeLists.txt`
- `runner/main.cc`
- `runner/my_application.cc`
- `runner/my_application.h`

File generati da non toccare di norma:

- `flutter/ephemeral/*`
- `flutter/generated_plugin_registrant.*`
- `flutter/generated_plugins.cmake`

### `apps/mobile/macos/`

Bootstrap desktop macOS.

File principali:

- `.gitignore`
- `Flutter/Flutter-Debug.xcconfig`
- `Flutter/Flutter-Release.xcconfig`
- `Runner.xcodeproj/project.pbxproj`
- `Runner.xcworkspace/...`
- `Runner/AppDelegate.swift`
- `Runner/Base.lproj/MainMenu.xib`
- `Runner/Configs/AppInfo.xcconfig`
- `Runner/Configs/Debug.xcconfig`
- `Runner/Configs/Release.xcconfig`
- `Runner/Configs/Warnings.xcconfig`
- `Runner/Info.plist`
- `Runner/MainFlutterWindow.swift`
- `Runner/DebugProfile.entitlements`
- `Runner/Release.entitlements`
- `RunnerTests/RunnerTests.swift`

File generati/boilerplate:

- `Flutter/GeneratedPluginRegistrant.swift`
- `Flutter/ephemeral/*`

### `apps/mobile/windows/`

Bootstrap desktop Windows.

File principali:

- `.gitignore`
- `CMakeLists.txt`
- `flutter/CMakeLists.txt`
- `runner/CMakeLists.txt`
- `runner/main.cpp`
- `runner/flutter_window.cpp`
- `runner/flutter_window.h`
- `runner/utils.cpp`
- `runner/utils.h`
- `runner/win32_window.cpp`
- `runner/win32_window.h`
- `runner/Runner.rc`
- `runner/resource.h`
- `runner/resources/app_icon.ico`
- `runner/runner.exe.manifest`

File generati:

- `flutter/generated_plugin_registrant.*`
- `flutter/generated_plugins.cmake`

### `apps/mobile/web/`

Bootstrap web Flutter.

File principali:

- `index.html`
- `manifest.json`
- `favicon.png`
- `icons/*`

---

## 7. `docs/`

Documentazione interna del progetto.

### `docs/api/`

Documenta le API per fase:

- `phase1.md`
- `phase2.md`
- `phase3.md`
- `phase4.md`

### `docs/architecture/`

Documenta architettura e stato:

- `phase1.md`
- `phase2.md`
- `phase3.md`
- `phase4.md`
- `remaining-work.md`
- `project-structure-guide.md`

---

## 8. `infra/`

Infrastruttura locale.

### `infra/compose/docker-compose.yml`

Stack locale:

- postgres
- redis
- minio
- minio-init
- backend
- worker
- beat

### `infra/init/minio-init.sh`

Script di init bucket MinIO.

### `infra/docker/`

Al momento cartella riservata, di fatto vuota.

---

## 9. `scripts/`

Cartella riservata per script futuri. Al momento vuota.

---

## 10. Dove modificare in base a quello che vuoi fare

### Voglio cambiare una schermata

Vai in:

- `apps/mobile/lib/features/<feature>/presentation/`

### Voglio cambiare un model lato mobile

Vai in:

- `apps/mobile/lib/features/<feature>/domain/`

### Voglio cambiare le chiamate API dal mobile

Vai in:

- `apps/mobile/lib/features/<feature>/data/`
- oppure `apps/mobile/lib/app/core/network/api_client.dart`

### Voglio cambiare le route backend

Vai in:

- `apps/backend/app/api/v1/`

### Voglio cambiare request/response API

Vai in:

- `apps/backend/app/schemas/`

### Voglio cambiare la logica di dominio

Vai in:

- `apps/backend/app/services/`

### Voglio cambiare le regole cliniche

Vai in:

- `apps/backend/app/rules/`

### Voglio cambiare la persistenza

Vai in:

- `apps/backend/app/models/`
- `apps/backend/app/repositories/`
- `apps/backend/alembic/versions/`

### Voglio cambiare AI

Vai in:

- `apps/backend/app/ai/`
- `apps/backend/app/services/insight_service.py`

### Voglio cambiare i worker asincroni

Vai in:

- `apps/backend/app/workers/`

### Voglio cambiare stack locale

Vai in:

- `infra/compose/docker-compose.yml`
- `infra/init/minio-init.sh`

## 11. Regola pratica finale

Quando tocchi una feature:

1. backend route in `api/v1`
2. DTO in `schemas`
3. logica in `services`
4. repository/model se cambia il dato
5. migrazione Alembic se cambia il DB
6. repository mobile
7. model mobile
8. schermata mobile
9. test backend/mobile

Se segui quest’ordine, ClinDiary resta coerente e manutenibile.
