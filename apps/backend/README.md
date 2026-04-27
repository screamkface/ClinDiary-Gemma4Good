# ClinDiary Backend

Backend FastAPI di ClinDiary.

Copre attualmente:

- auth, onboarding e profilo clinico
- diario giornaliero, sintomi, parametri e timeline
- documenti clinici con processing asincrono e revisione manuale
- archivio documentale a cartelle con move-file, breadcrumb e ricerca
- query documentale RAG con chunking, embeddings, rerank e citazioni
- query documentale RAG con retrieval SQL ottimizzato su PostgreSQL, chunking, embeddings, rerank e citazioni
- OCR provider-agnostic per immagini/scansioni (default `paddleocr`, con fallback `ocr_pending`)
- insights prudenti, alert clinici e report PDF con runtime locale Gemma o fallback `rule_based`
- screenings, aderenza farmaci e notifiche
- worker Celery e beat per sync periodico notifiche
- hardening reale: request tracing HTTP, rate limiting auth Redis-backed con fallback, metriche `/metrics` e audit trail persistente
- document hardening con hash SHA-256, validazione firma file e scan hook configurabile
- notifiche adapter-ready con device registration e canali push/email opzionali
- scheduling farmaci avanzato con giorni specifici, cicli e pause
- API per edit/pause/resume/delete degli schedule farmaci
- il backend non genera reminder farmaci: i promemoria terapia sono pianificati localmente dall'app mobile
- modulo `devices` Wave 1 con catalogo provider, connessioni profilo-scoped, import job e ingest manuale dove supportato

## Hackathon MVP: Private / Local Daily Recap

Il percorso hackathon e focalizzato sul recap giornaliero privato locale.

Per la demo principale su Android:

- prompt on-device: `GET /api/v1/insights/daily/on-device-prompt`
- inferenza finale: eseguita sul telefono via LiteRT-LM
- proof UI: mostrata nell'app in modalita `Sul dispositivo`

Percorso alternativo locale lato host:

- endpoint recap: `GET /api/v1/insights/daily/private-local`
- regenerate: `POST /api/v1/insights/daily/private-local/regenerate`
- proof endpoint: `GET /api/v1/insights/local-status`

Il recap `on-device`:

- riusa il payload clinico esistente di `InsightService`
- lo minimizza per il solo recap giornaliero
- restituisce `system_prompt` e `user_prompt` prudenti
- delega al telefono solo l'inferenza finale
- non persiste il risultato in `ai_summaries`
- non invia il testo finale a un provider cloud

Il recap `private-local` lato host:

- riusa il payload clinico esistente di `InsightService`
- lo minimizza per il solo recap giornaliero
- forza il provider alias `local_gemma4`
- non persiste il risultato in `ai_summaries`
- ricade su `rule_based` se il runtime locale non e disponibile

Il backend continua a tenere fuori dal modello:

- red flags
- screening/prevenzione
- follow-up deterministici
- reminder farmaci

## Demo on-device Android

1. Copia un modello LiteRT-LM sul telefono:

```bash
bash scripts/push_android_litert_model.sh /percorso/al/tuo/gemma-4-E2B-it.litertlm
```

2. Avvia seed + app:

```bash
DATABASE_URL=postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary .venv/bin/clindiary-seed
bash scripts/run_android_app.sh --skip-seed
```

3. Nell'app:

- apri `Recap AI`
- scegli `Giorno`
- scegli `Sul dispositivo`
- se il modello non e ancora presente, usa `Importa modello .litertlm`
- per dettagli file, sostituzione o rimozione usa `Gestisci modello`
- verifica la proof card `LiteRT-LM Android`

## Struttura tecnica

- `app/main.py`: entrypoint FastAPI
- `app/core/metrics.py`: registry metriche runtime esportate su `/metrics`
- `app/api/v1/`: route REST
- `app/schemas/`: DTO request/response
- `app/services/`: business logic
- `app/rules/`: regole cliniche deterministiche
- `app/ai/`: narrativa prudente e adapter AI
- `app/ai/document_rag_provider.py`: adapter embeddings/rerank/answer per query documentale
- `app/models/`: schema SQLAlchemy
- `app/repositories/`: accesso dati
- `app/workers/`: Celery worker e task background
- `alembic/versions/`: migrazioni database

## Avvio locale

1. Crea il virtualenv e installa le dipendenze:

```bash
python3 -m venv .venv
.venv/bin/pip install -e .[dev]
```

Per attivare PaddleOCR:

```bash
.venv/bin/pip install -e .[dev,ocr]
```

Per usare anche il fallback OCR secondario:

```bash
sudo apt-get install tesseract-ocr
```

Per usare Gemma locale:

```bash
cp .env.gemma-local.example .env
```

Per accedere con Google:

```bash
GOOGLE_OAUTH_CLIENT_ID=il-tuo-client-id-web-o-android
```

Il login Google usa un `id_token` verificato dal backend e poi emette i normali token ClinDiary.

Se il provider embeddings non supporta il parametro `dimensions`, ClinDiary ritenta automaticamente senza quel campo e salva comunque la dimensione reale ritornata in `document_chunks.embedding_dimensions`.

2. Copia `.env.example` in `.env` se vuoi configurazione locale custom.

3. Dalla root del monorepo avvia i servizi:

```bash
docker compose -f infra/compose/docker-compose.yml up -d postgres redis minio minio-init
```

Il compose locale usa `pgvector/pgvector:pg16`, quindi l'estensione `vector` richiesta dalla migration documentale e` disponibile di default.

4. Esegui le migrazioni:

```bash
alembic upgrade head
```

5. Carica i dati demo:

```bash
clindiary-seed
```

6. Avvia l'API:

```bash
uvicorn app.main:app --reload
```

7. Avvia il worker documenti/notifiche:

```bash
celery -A app.workers.celery_app.celery_app worker --loglevel=info
```

8. Avvia il beat scheduler:

```bash
celery -A app.workers.celery_app.celery_app beat --loglevel=info
```

Per predisporre il container backend/worker con OCR nel build Docker, usa `INSTALL_OCR=true` come build arg.

Per push vendor-backed puoi configurare in `.env`:

- `NOTIFICATION_PUSH_PROVIDER=fcm` con `NOTIFICATION_FCM_PROJECT_ID` e token/accesso service account
- `NOTIFICATION_PUSH_PROVIDER=apns` con `NOTIFICATION_APNS_*`

Smoke OCR locale:

```bash
clindiary-ocr-smoke
clindiary-ocr-smoke --file /percorso/documento.png
```

Smoke AI locale:

```bash
clindiary-ai-smoke
clindiary-ai-smoke --require-local-runtime
clindiary-ai-smoke --payload /percorso/payload.json --require-local-runtime
clindiary-ai-eval
clindiary-ai-eval --inputs /percorso/casi-curati
clindiary-ai-eval --inputs /percorso/casi-curati --require-local-runtime
```

Il comando AI usa un payload di prova interno se non ne passi uno. Con `--require-local-runtime` fallisce se il runtime locale non e disponibile o se il backend ricade sul fallback `rule_based`.
`clindiary-ai-eval` fa la stessa verifica su piu casi curati e controlla anche che il riepilogo rispetti la struttura clinica attesa.

Per il recap locale Gemma:

```bash
bash ../scripts/setup_local_gemma_ollama.sh --keep-server
```

Questo bootstrap locale usa `embeddinggemma` per il retrieval e lascia il reranking a `rule_based`, che e la scelta piu rapida per la demo.

Per usare l'overlay locale senza modificare `.env`, avvia il mobile/backend con:

```bash
bash ../scripts/run_android_app.sh --local-gemma --skip-seed
```

Smoke rapido:

```bash
clindiary-ai-smoke --profile private_local_daily
bash ../../scripts/smoke_local_gemma_ollama.sh
EXPECT_FALLBACK=1 bash ../../scripts/smoke_local_gemma_ollama.sh
```

Il secondo comando verifica il proof endpoint e poi chiama il recap `private-local`.
Con `EXPECT_FALLBACK=1` puoi verificare esplicitamente il comportamento di fallback se il runtime locale e spento o non configurato.

Endpoint documentali RAG:

- `POST /api/v1/documents/query`
- `POST /api/v1/documents/reindex`
- `POST /api/v1/documents/{id}/reindex`

Endpoint modulo device Wave 1:

- `GET /api/v1/devices/overview`
- `POST /api/v1/devices/providers/{provider_code}/link`
- `DELETE /api/v1/devices/connections/{connection_id}`
- `POST /api/v1/devices/connections/{connection_id}/sync`
- `POST /api/v1/devices/connections/{connection_id}/measurements`

Smoke notifiche locale:

```bash
clindiary-notification-smoke
clindiary-notification-smoke --payload /percorso/notification.json
clindiary-notification-smoke --payload /percorso/notification.json --require-delivery-provider

clindiary-notification-audit
clindiary-notification-audit --require-delivery-provider

clindiary-screening-links-audit
clindiary-screening-links-audit --timeout 15
```

Esempio payload:

```json
{
  "title": "ClinDiary: test delivery",
  "body": "Messaggio di verifica",
  "notification_type": "report_ready",
  "priority": "normal",
  "email_address": "tuo@example.com",
  "devices": [
    {
      "platform": "android",
      "device_token": "token-di-prova",
      "device_label": "Mi 10"
    }
  ]
}
```

Con `--require-delivery-provider` il comando fallisce se il provider ricade su `log_only` oppure se nessun canale reale viene testato.

L'equivalente API per l'app e `POST /api/v1/notifications/test-delivery`.

## Script utili

Da `pyproject.toml`:

- `clindiary-api`
- `clindiary-seed`
- `clindiary-worker`
- `clindiary-beat`
- `clindiary-ai-smoke`
- `clindiary-ai-eval`
- `clindiary-ocr-smoke`
- `clindiary-notification-smoke`
- `clindiary-notification-audit`
- `clindiary-screening-links-audit`

## Test

```bash
pytest
```

## Dove modificare cosa

- nuova API: `app/api/v1/`, `app/schemas/`, `app/services/`
- nuova tabella: `app/models/` + nuova migrazione Alembic
- nuova regola clinica: `app/rules/`
- nuovo flusso AI: `app/ai/`
- nuovo job asincrono: `app/workers/`
