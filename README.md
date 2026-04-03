# ClinDiary

ClinDiary e una baseline production-oriented per una app clinica mobile con diario giornaliero, timeline sanitaria unica, archivio documentale, supporto AI prudente, alert clinici spiegabili, screening/prevenzione, aderenza terapeutica, inbox notifiche, report PDF e sync wearable/smartwatch. In questa repository Fase 1, Fase 2, Fase 3 e Fase 4 sono implementate e Fase 5 e ormai quasi tutta chiusa lato codice, con hardening reale backend/mobile.

## Stato attuale

Completato fino a Fase 4:

- auth con register, login, refresh token rotation, logout e reset password
- onboarding con consenso dati sanitari
- profilo clinico con allergie, patologie note, farmaci e familiarita
- diario giornaliero con sintomi, parametri e note
- timeline clinica base aggregata
- documenti clinici con upload PDF/JPG/PNG, archivio, dettaglio e viewer URL firmata
- archivio documenti a cartelle con breadcrumb, spostamento file e ricerca
- processing asincrono via Celery con estrazione testo da PDF digitali e OCR configurabile per immagini/scansioni
- parsing deterministico base per referti laboratorio e imaging
- revisione manuale documenti con conferma/correzione di metadata, testo e parsing strutturato
- retrieval documentale con chunking, embeddings Regolo, rerank e risposta con citazioni
- retrieval documentale ottimizzato su PostgreSQL con full-text search indicizzata e ranking SQL dei candidati
- baseline billing/entitlements con piani `free` e `AI Plus`, gating server-side delle feature AI e paywall mobile contestuale
- archivio documenti differenziato per piano: `free` salva i file solo sul dispositivo con cartelle e ricerca locale; `AI Plus` usa il cloud ClinDiary con OCR, parsing, reindex e query documentale
- modulo `Dispositivi` Wave 1 con catalogo provider per `OMRON`, `Withings`, `iHealth`, `A&D Medical` e `Dexcom`, connessioni profilo-scoped, import job tracciati e ingest manuale per i flussi gia` supportati
- timeline documentale con eventi di upload e processing
- insights prudenti giornalieri, settimanali e pre-visita
- red flags engine separato dalla narrativa AI
- alert center con risoluzione manuale
- report PDF server-side con download tramite URL firmata
- modulo screening e prevenzione con catalogo, eleggibilita deterministica, stato personale e mark-done
- reminder e inbox notifiche per check-in, screening, documenti, report e alert clinici
- preferenze notifiche utente con toggle per categorie e salvaguardia dell'alert center separato
- reminder farmaci pianificati localmente dall'app sul dispositivo, non dal server
- sync smartwatch/telefono via Health Connect e Apple Health con salvataggio giornaliero aggregato e uso dei dati nei recap AI
- farmaci e aderenza con schedule base, conferma assunzione e storico logs
- report `screening_status_report` alimentato dai dati reali della Fase 4
- app Flutter con login, onboarding, home, diario, timeline, documenti e profilo
- app Flutter con schermate insights, alerts, reports, screenings, medications e notifications collegate al backend
- cache locale Drift e token storage sicuro
- audit trail persistente per eventi sensibili
- metriche runtime via `/metrics` e trace HTTP con request id
- upload documenti con verifica firma MIME, hash SHA-256 e hook di scanning configurabile
- OCR con retry e fallback secondario `tesseract`
- recap AI persistiti con metadata `provider/model`
- API per modifica, pausa, ripresa e rimozione schedule farmaci senza ricreare la terapia
- console mobile `Sync locale` per vedere coda offline e trace rete
- test minimi backend e mobile

Roadmap successiva:

- validazione provider AI reale con tua chiave Regolo AI
- integrazione nativa StoreKit / Google Play Billing sopra il baseline AI Plus gia presente
- credenziali reali FCM/APNs/SMTP e test end-to-end dei canali esterni
- validazione OCR su scansioni reali difficili e wearable su dispositivi veri
- dataset screening regionali/ASL con link istituzionali verificati

## Struttura repository

```text
apps/
  backend/
  mobile/
docs/
  api/
  architecture/
infra/
  compose/
  init/
scripts/
```

## Prerequisiti

- Python 3.12+
- Flutter 3.35+
- Docker 29+
- Android `minSdk 26` per la build mobile con plugin salute/wearable

## Avvio rapido

### Un solo comando per Android

Se vuoi avviare tutto in una volta sola per Android:

```bash
bash scripts/run_android_app.sh
```

Su Windows usa PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1
```

Lo script:

- avvia `postgres`, `redis`, `minio`
- prepara il backend se manca il virtualenv
- esegue migration e seed demo
- avvia API, worker e beat se non sono gia attivi
- rileva il device Android collegato
- configura `adb reverse` quando possibile
- lancia `flutter run` con `API_BASE_URL` corretto

Opzioni utili:

```bash
bash scripts/run_android_app.sh --device-id KFJV9XHIAM4LWS8H
bash scripts/run_android_app.sh --skip-seed
bash scripts/run_android_app.sh --keep-background
make android-run
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id KFJV9XHIAM4LWS8H
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id KFJV9XHIAM4LWS8H --prefer-lan
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --backend-only
powershell -ExecutionPolicy Bypass -File scripts/stop_android_backend.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --skip-seed
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --keep-background
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --with-ocr
```

Per usare il telefono senza dipendere dal cavo USB:

- compila almeno una volta l'app con `--prefer-lan` oppure con `--api-base-url http://IP_DEL_PC:8000`
- assicurati che telefono e PC siano sulla stessa Wi-Fi
- poi puoi scollegare il cavo e lasciare acceso solo il backend con `--backend-only`

1. Avvia l'infrastruttura locale:

```bash
docker compose -f infra/compose/docker-compose.yml up -d postgres redis minio minio-init
```

Il compose usa `pgvector/pgvector:pg16`, quindi la migration dei `document_chunks` trova gia disponibile l'estensione `vector`.

2. Installa il backend:

```bash
python3 -m venv apps/backend/.venv
apps/backend/.venv/bin/pip install -e apps/backend[dev]
```

Se non hai ancora un file `.env`, puoi comunque avviare ClinDiary con i valori di default locali: il progetto parte lo stesso e usa il fallback rule-based.
Per attivare Regolo AI o configurazioni personalizzate, crea prima `apps/backend/.env` copiando `apps/backend/.env.example`.

Per attivare OCR con PaddleOCR:

```bash
apps/backend/.venv/bin/pip install -e apps/backend[dev,ocr]
```

Per usare il fallback Tesseract sul tuo host installa anche il binario `tesseract` di sistema.

Per usare un provider AI OpenAI-compatible:

```bash
export AI_PROVIDER=openai_compatible
export AI_BASE_URL=https://your-provider.example/v1
export AI_API_KEY=your-secret
```

Per usare Regolo AI:

1. Crea `apps/backend/.env` partendo da `apps/backend/.env.example`
2. imposta almeno:

```bash
AI_PROVIDER=regolo_ai
REGOLO_API_KEY=incolla-qui-la-tua-chiave
REGOLO_BASE_URL=https://api.regolo.ai/v1
REGOLO_MODEL_NAME=minimax-m2.5
DOCUMENT_ANSWER_MODEL_NAME=qwen3-8b
DOCUMENT_EMBEDDING_MODEL_NAME=qwen3-embedding-8b
DOCUMENT_EMBEDDING_DIMENSIONS=1024
DOCUMENT_RERANKER_MODEL_NAME=qwen3-reranker-4b
WITHINGS_CLIENT_ID=...
WITHINGS_CLIENT_SECRET=...
WITHINGS_REDIRECT_URI=https://backend.example.com/oauth/withings/callback
IHEALTH_CLIENT_ID=...
IHEALTH_CLIENT_SECRET=...
IHEALTH_REDIRECT_URI=https://backend.example.com/oauth/ihealth/callback
DEXCOM_CLIENT_ID=...
DEXCOM_CLIENT_SECRET=...
DEXCOM_REDIRECT_URI=https://backend.example.com/oauth/dexcom/callback
```

Per iniziare la migrazione Gemma in modo graduale:

```bash
SUMMARY_AI_PROVIDER=gemma
SUMMARY_AI_RUNTIME_MODE=remote
SUMMARY_AI_MODEL_NAME=gemma-4
DOCUMENT_ANSWER_PROVIDER=gemma
DOCUMENT_EMBEDDING_PROVIDER=gemma
DOCUMENT_EMBEDDING_RUNTIME_MODE=remote
DOCUMENT_EMBEDDING_MODEL_NAME=embeddinggemma
DOCUMENT_RERANKER_PROVIDER=regolo_ai
GEMMA_API_KEY=incolla-qui-la-tua-chiave
GEMMA_BASE_URL=https://your-gemma-gateway.example/v1
```

Questa combinazione sposta verso Gemma:

- recap/report
- answer generation documentale
- embeddings documentali

mentre il rerank resta sul path Regolo/Qwen per mantenere il comportamento attuale piu stabile.

`DOCUMENT_EMBEDDING_DIMENSIONS=1024` e il compromesso consigliato tra spazio, latenza e qualita. Se il provider non supporta il parametro, ClinDiary ritenta automaticamente senza `dimensions` e continua a funzionare.

Smoke utili per la migrazione:

```bash
cd apps/backend
clindiary-ai-smoke --profile gemma_summary --require-external-provider
clindiary-document-rag-smoke --profile embeddinggemma --require-external-provider
clindiary-document-rag-smoke --mode answer --profile default --require-external-provider
```

Per il path locale su backend host attraverso le fasi 1-3, il setup consigliato e`:

```bash
SUMMARY_AI_PROVIDER=gemma
SUMMARY_AI_RUNTIME_MODE=local
DOCUMENT_ANSWER_PROVIDER=gemma
DOCUMENT_ANSWER_RUNTIME_MODE=local
DOCUMENT_EMBEDDING_PROVIDER=gemma
DOCUMENT_EMBEDDING_RUNTIME_MODE=local
DOCUMENT_RERANKER_PROVIDER=regolo_ai
LOCAL_LLM_BACKEND=ollama
LOCAL_LLM_BASE_URL=http://127.0.0.1:11434
LOCAL_LLM_MODEL_NAME=<your-local-gemma-model-tag>
LOCAL_EMBEDDING_MODEL_NAME=<your-local-embeddinggemma-model-tag>
LOCAL_EMBEDDING_DIMENSIONS=1024
LOCAL_MAX_CONTEXT_TOKENS=8192
```

Questo attiva Gemma locale per recap/report, answer generation documentale e embeddings senza toccare il mobile e senza spostare logica clinica deterministica nell'LLM. Per server locali OpenAI-compatible puoi usare `LOCAL_LLM_BACKEND=llama_cpp`, `vllm` o `openai_compatible`. Il rerank puo` restare su `regolo_ai` oppure sul fallback `rule_based`.

Per un target locale ripetibile con Ollama user-space:

```bash
bash scripts/setup_local_gemma_ollama.sh --keep-server
bash scripts/smoke_local_gemma_ollama.sh
```

Questo bootstrap usa:

- `gemma4:e2b` come modello generativo locale
- `embeddinggemma` come modello embeddings locale
- porta dedicata `11435`
- env hint generato in `.runtime/ollama-local/gemma-local.env`
- `AI_TIMEOUT_SECONDS=300` per evitare timeout prematuri su inferenza CPU locale

Se la macchina non ha abbastanza RAM libera per `gemma4:e2b`, puoi usare un fallback solo per smoke/dev:

```bash
LOCAL_GEMMA_MODEL=gemma3n:e2b bash scripts/setup_local_gemma_ollama.sh --keep-server
LOCAL_LLM_MODEL_NAME=gemma3n:e2b bash scripts/smoke_local_gemma_ollama.sh
```

Il target architetturale resta `Gemma 4`; `gemma3n:e2b` serve solo come profilo di verifica per host locali piu` stretti.

Se vuoi un profilo versionato da copiare nel backend, parti da:

- `apps/backend/.env.gemma-local.example`

Per la `Wave 1` dei device clinici:

- `OMRON` e` modellato come connettore partner/SDK-BLE, quindi richiede onboarding vendor o bridge mobile dedicato
- `Withings`, `iHealth` e `Dexcom` usano credenziali OAuth server-side e possono essere bootstrap-ati anche con token manuali in ambienti partner/debug
- `A&D Medical` supporta gia` salvataggio API key e ingest manuale dal client ClinDiary
- senza credenziali/approval vendor il modulo `Dispositivi` resta comunque usabile per catalogo, setup guidato, bootstrap dei connettori e tracking degli import

Se vuoi ancora usare Gemini, il blocco rimane supportato con:

```bash
AI_PROVIDER=gemini_ai_studio
AI_MODEL_NAME=gemini-2.5-flash
GEMINI_API_KEY=incolla-qui-la-tua-chiave
```

Se usi Docker Compose puoi anche creare `.env` nella root partendo da [.env.example](/home/nicola/Documents/ClinDiary/.env.example), oppure lanciare:

```bash
docker compose --env-file apps/backend/.env -f infra/compose/docker-compose.yml up -d --build backend worker beat
```

### Billing AI Plus in debug

ClinDiary ora separa il core clinico gratuito dalle capability AI a pagamento:

- restano free: diario, timeline, documenti locali sul dispositivo, prevenzione, storico, dossier, reminder farmaci
- richiedono AI Plus: archivio documenti cloud, OCR/parsing/reindex documenti, recap AI, report AI, `Chiedi ai documenti`

Nel backend il gating e` gia reale. Finche non colleghiamo StoreKit/Google Play Billing puoi testarlo in debug con:

```bash
curl -X POST http://localhost:8000/api/v1/billing/dev/activate \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"plan_code":"ai_plus_yearly"}'
```

oppure direttamente dall'app nella schermata `ClinDiary AI Plus`.

Quando attivi il piano demo AI Plus in debug, l'app passa anche dal vault documentale locale all'archivio cloud. Questo ti permette di testare entrambe le modalita senza cambiare build.

3. Esegui le migration:

```bash
DATABASE_URL=postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary \
apps/backend/.venv/bin/alembic -c apps/backend/alembic.ini upgrade head
```

4. Carica seed demo:

```bash
DATABASE_URL=postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary \
apps/backend/.venv/bin/clindiary-seed
```

5. Avvia l'API:

```bash
DATABASE_URL=postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary \
apps/backend/.venv/bin/uvicorn app.main:app --app-dir apps/backend --reload
```

6. Avvia il worker documentale:

```bash
DATABASE_URL=postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary \
REDIS_URL=redis://localhost:6379/0 \
MINIO_ENDPOINT=localhost:9000 \
MINIO_ACCESS_KEY=minioadmin \
MINIO_SECRET_KEY=minioadmin \
MINIO_BUCKET=clindiary \
MINIO_SECURE=false \
PYTHONPATH=apps/backend apps/backend/.venv/bin/celery -A app.workers.celery_app.celery_app worker --loglevel=info
```

7. Avvia il beat scheduler notifiche:

```bash
DATABASE_URL=postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary \
REDIS_URL=redis://localhost:6379/0 \
NOTIFICATION_SYNC_INTERVAL_MINUTES=15 \
PYTHONPATH=apps/backend apps/backend/.venv/bin/celery -A app.workers.celery_app.celery_app beat --loglevel=info
```

8. Verifica OCR runtime:

```bash
PYTHONPATH=apps/backend apps/backend/.venv/bin/clindiary-ocr-smoke
```

Per provare un file reale:

```bash
PYTHONPATH=apps/backend apps/backend/.venv/bin/clindiary-ocr-smoke --file /percorso/documento.png
```

9. Avvia il mobile:

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

Per Android Emulator usa normalmente `http://10.0.2.2:8000` come `API_BASE_URL`.

## Query sui documenti

ClinDiary ora supporta anche una query documentale con citazioni:

- backend: `POST /api/v1/documents/query`
- mobile: pulsante `Chiedi ai file` dentro la schermata `Documenti`

Il flusso e:

1. upload/process/review documento
2. indicizzazione asincrona in `document_chunks`
3. retrieval ibrido metadata-first
4. embeddings + rerank Regolo
5. risposta finale con citazioni apribili

Per forzare una reindicizzazione:

```bash
curl -X POST http://localhost:8000/api/v1/documents/reindex \
  -H "Authorization: Bearer <ACCESS_TOKEN>"
```

## Demo seed

- email: `demo@clindiary.local`
- email: `demo@clindiary.app`
- password: `ChangeMe123!`

Il seed demo include:

- terapia attiva con schedule giornaliero
- uno storico minimo di aderenza farmaco
- catalogo screening Italia con stato personale calcolabile
- notifiche inbox generate al primo accesso

## Test

Backend:

```bash
apps/backend/.venv/bin/pytest apps/backend/tests
```

Mobile:

```bash
cd apps/mobile
flutter analyze
flutter test
```

## Verifica eseguita

- `python3 -m compileall apps/backend/app apps/backend/tests`
- `apps/backend/.venv/bin/pytest apps/backend/tests`
- `cd apps/mobile && flutter analyze`
- `cd apps/mobile && flutter test`
- `cd apps/mobile && flutter build apk --debug`

## Note implementative

- i dati sanitari restano separati tra UI, business logic e persistence layer
- in Fase 2/Fase 5 l'estrazione testo usa `pypdf` per PDF digitali e provider OCR configurabile (`OCR_PROVIDER`) per immagini/scansioni
- il build Docker di `backend` e `worker` verifica davvero il runtime OCR quando `INSTALL_OCR=true`
- classificazione e parsing documentale sono deterministici e spiegabili, senza AI clinica
- in Fase 3/Fase 5 la narrativa AI resta prudente e non diagnostica; prima vengono sempre considerate le regole red flags e il provider esterno degrada sempre sul fallback rule-based
- oltre all'adapter OpenAI-compatible e ora disponibile anche `gemini_ai_studio` via API key Google AI Studio
- in Fase 4 screening, reminder e aderenza farmaci usano regole deterministiche e persistence separate (`rules/`, `services/`, `repositories/`)
- le notifiche sono in-app inbox, con `read_status`, priorita e deduplica per evitare duplicazioni inutili; Fase 5 aggiunge canali adapter-ready `push/email`
- le preferenze notifiche si gestiscono da app e il sync periodico puo girare in background tramite Celery Beat
- i reminder farmaci usano scheduling locale su device (`flutter_local_notifications` + `timezone`); il backend mantiene terapia e preferenze ma non genera `medication_reminder`
- il mobile salva trace rete locali e una queue offline minima per operazioni JSON critiche
- il mobile mette in coda anche alcune azioni notifiche (`mark read`, preferenze) e offre una schermata `Sync locale` per flush manuale/debug
- il backend espone `/metrics` in formato Prometheus-like per osservabilita tecnica locale
- i documenti salvano hash SHA-256, esito scan e validazione firma file per rendere il flusso piu spiegabile
- il backend puo gia spedire push via `webhook`, `fcm` o `apns` se configuri le credenziali; il codice e pronto ma la prova reale dipende dai tuoi provider
- report e documenti usano storage file separato dai metadata relazionali
