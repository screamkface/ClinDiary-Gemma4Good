# ClinDiary

ClinDiary e una baseline production-oriented per una app clinica mobile con diario giornaliero, timeline sanitaria unica, archivio documentale, supporto AI prudente, alert clinici spiegabili, screening/prevenzione, aderenza terapeutica, inbox notifiche, report PDF e sync wearable/smartwatch. In questa repository Fase 1, Fase 2, Fase 3 e Fase 4 sono implementate e Fase 5 e ormai quasi tutta chiusa lato codice, con hardening reale backend/mobile.

## Gemma 4 Good Hackathon MVP

La submission e focalizzata su una sola hero feature:

- `Private / Local Daily Recap`

In pratica:

- ClinDiary raccoglie sintomi, check-up, parametri, terapia, wearable e timeline
- il motore deterministico continua a gestire alert, screening, prevenzione e follow-up hard-coded
- il recap giornaliero puo essere richiesto anche tramite percorso `Sul dispositivo`
- il percorso `Sul dispositivo` usa LiteRT-LM su Android e un modello `.litertlm` caricato sul telefono
- il backend continua a esistere come orchestratore del prompt prudente e come fallback privato locale lato host
- il recap locale non viene persistito in `ai_summaries`: e transiente e separato dal recap cloud/default
- il frontend mostra badge e proof card per distinguere percorso cloud, percorso locale host e percorso on-device

Per il MVP hackathon:

- `Gemma 4` e la famiglia di modelli target per il recap locale
- `Gemma 4 On-device` viene mostrato in UI solo quando il runtime Android rileva davvero un modello coerente
- se il runtime locale e attivo ma il label non e definitivo, la UI usa `On-device locale` o `Modalita privata locale`
- il fallback resta `rule_based`

## Locale vs cloud

- `Cloud/default recap`: usa il provider AI configurato normalmente per i recap persistiti
- `On-device recap`: usa `GET /api/v1/insights/daily/on-device-prompt` per ottenere il prompt minimizzato e genera il testo direttamente su Android via LiteRT-LM
- `Private/local recap`: usa `GET /api/v1/insights/daily/private-local` e `POST /api/v1/insights/daily/private-local/regenerate` come percorso alternativo locale lato host
- `Proof locale`: `GET /api/v1/insights/local-status`

Limite intenzionale del MVP:

- il focus e solo sul `daily recap`
- document RAG locale resta fuori dalla hero feature
- la logica clinica deterministica non viene spostata nel modello

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
- retrieval documentale con chunking, embeddings locali Gemma, rerank `rule_based` e risposta con citazioni
- retrieval documentale ottimizzato su PostgreSQL con full-text search indicizzata e ranking SQL dei candidati
- baseline billing/entitlements con piani `free` e `AI Plus`, gating server-side delle feature AI e paywall mobile contestuale
- archivio documenti differenziato per piano: `free` salva i file solo sul dispositivo con cartelle e ricerca locale; `AI Plus` usa il cloud ClinDiary con OCR, parsing, reindex e query documentale
- modulo `Dispositivi` Wave 1 con catalogo provider, connessioni profilo-scoped, import job tracciati e ingest manuale per i flussi gia` supportati
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

- validazione runtime Gemma locale su casi reali
- integrazione nativa StoreKit / Google Play Billing sopra il baseline AI Plus gia presente
- credenziali reali FCM/APNs/SMTP e test end-to-end dei canali esterni
- validazione OCR su scansioni reali difficili e wearable su dispositivi veri
- dataset screening regionali/ASL con link istituzionali verificati

## Judge Path

Percorso rapido verificabile in meno di 3 minuti:

1. imposta il backend in modalita hackathon e locale, per esempio:

```bash
bash scripts/push_android_litert_model.sh /percorso/al/tuo/gemma-4-E2B-it.litertlm
```

2. avvia backend + mobile e ricarica il seed demo:

```bash
DATABASE_URL=postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary apps/backend/.venv/bin/clindiary-seed
bash scripts/run_android_app.sh --skip-seed
```

3. accedi con:

```text
demo@clindiary.app
ChangeMe123!
```

4. dalla Home apri `Scenari demo`, cambia profilo e tocca `Apri Recap AI`
5. nella schermata `Recap AI`, scegli `Giorno` e `Sul dispositivo`
6. se non c'e ancora un modello, lascia completare `Preparing local Gemma model` oppure apri `Gestisci modello`
7. usa `Prepare/download Gemma` per il download app-owned, oppure importa un `.litertlm` che ClinDiary copiera nel proprio path
8. se vuoi controllare path, dimensione file, prompt di test o rimuovere il modello, usa `Gestisci modello`
9. verifica:
   - badge provider on-device
   - proof card con provider/runtime/modello/backend
   - `Cloud esterno usato: No`

Verifica tecnica equivalente:

```bash
cd apps/mobile
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

La vecchia copia manuale in `/sdcard/Android/data/.../files/models` non e piu il path di bootstrap dell'app. Il modello deve essere scaricato/importato dal flusso app-owned e poi verificato con `Run test prompt`.

Se vuoi mostrare anche il percorso locale lato host come confronto tecnico:

```bash
bash scripts/setup_local_gemma_ollama.sh --keep-server
bash scripts/smoke_local_gemma_ollama.sh
```

Questo profilo locale usa `embeddinggemma` per il retrieval e mantiene il reranking `rule_based`, cosi la demo resta piu veloce e leggera.

## Video Demo Path

Sequenza consigliata per un video di 2-3 minuti:

1. Home: mostra che ClinDiary non e un chatbot ma una app salute completa
2. `Scenari demo`: passa da Scenario A a Scenario B
3. `Recap AI`: seleziona `Sul dispositivo`
4. se serve, usa `Importa modello .litertlm` direttamente nell'app
5. fai vedere il badge provider, la proof card e il path del modello sul device
6. genera o rigenera il recap del giorno
7. chiudi mostrando che alert/screening/prevenzione restano deterministicamente separati dal modello

## Safety Boundaries

- nessuna diagnosi
- nessuna prescrizione o dose
- nessun uso del modello per red flags, screening o prevenzione deterministica
- il recap usa solo il payload disponibile
- il testo resta prudente e orientato all'italiano clinico non diagnostico

## Known Limitations

- il percorso `Sul dispositivo` oggi e implementato solo su Android, non su iOS
- il modello `.litertlm` puo essere provisionato via script `adb` oppure importato direttamente dall'app
- il recap `Sul dispositivo` oggi genera il testo sul telefono, ma costruisce ancora il prompt prudente tramite backend ClinDiary; la modalita full-offline end-to-end resta step successivo
- `Gemma 4` resta il target di submission; su device o host di sviluppo deboli puo servire un modello Gemma piu piccolo solo per smoke/dev
- il recap locale e volutamente piu corto e non copre l'intera piattaforma AI
- document RAG locale non e il centro della demo hackathon

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

Per il debug Wi-Fi Android con backend incluso usa:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --connect-address 192.168.1.42:5555
powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --pair-address 192.168.1.42:37123 --pair-code 123456 --connect-address 192.168.1.42:5555
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

Se non hai ancora un file `.env`, puoi comunque avviare ClinDiary con i valori di default locali: il progetto parte lo stesso e usa Gemma locale se disponibile, altrimenti il fallback rule-based.
Per una configurazione locale esplicita, crea `apps/backend/.env` copiando `apps/backend/.env.example` oppure `apps/backend/.env.gemma-local.example`.

Per attivare OCR con PaddleOCR:

```bash
apps/backend/.venv/bin/pip install -e apps/backend[dev,ocr]
```

Per usare il fallback Tesseract sul tuo host installa anche il binario `tesseract` di sistema.

Per usare il profilo locale Gemma:

```bash
cp apps/backend/.env.gemma-local.example apps/backend/.env
```

`DOCUMENT_EMBEDDING_DIMENSIONS=1024` resta il compromesso consigliato tra spazio e latenza. Se il runtime locale non supporta il parametro, ClinDiary ritenta automaticamente senza `dimensions` e continua a funzionare.

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
4. embeddings locali Gemma + rerank `rule_based`
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
- in Fase 3/Fase 5 la narrativa AI resta prudente e non diagnostica; prima vengono sempre considerate le regole red flags e il runtime locale degrada sempre sul fallback rule-based
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
