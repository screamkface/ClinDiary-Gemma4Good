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
- insights prudenti, alert clinici e report PDF con adapter `openai_compatible` o `gemini_ai_studio`
- screenings, aderenza farmaci e notifiche
- worker Celery e beat per sync periodico notifiche
- hardening reale: request tracing HTTP, rate limiting auth Redis-backed con fallback, metriche `/metrics` e audit trail persistente
- document hardening con hash SHA-256, validazione firma file e scan hook configurabile
- notifiche adapter-ready con device registration, push `webhook/fcm/apns` ed email smtp/log-only
- scheduling farmaci avanzato con giorni specifici, cicli e pause
- API per edit/pause/resume/delete degli schedule farmaci
- il backend non genera reminder farmaci: i promemoria terapia sono pianificati localmente dall'app mobile
- modulo `devices` Wave 1 con catalogo provider (`OMRON`, `Withings`, `iHealth`, `A&D Medical`, `Dexcom`), connessioni profilo-scoped, import job e ingest manuale dove supportato

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

Per testare un provider AI OpenAI-compatible:

```bash
export AI_PROVIDER=openai_compatible
export AI_BASE_URL=https://your-provider.example/v1
export AI_API_KEY=your-secret
```

Per Gemini via Google AI Studio:

```bash
cp .env.example .env
```

Poi in `.env`:

```bash
AI_PROVIDER=gemini_ai_studio
AI_MODEL_NAME=gemini-2.5-flash
GEMINI_API_KEY=incolla-qui-la-tua-chiave
```

Per accedere con Google:

```bash
GOOGLE_OAUTH_CLIENT_ID=il-tuo-client-id-web-o-android
```

Il login Google usa un `id_token` verificato dal backend e poi emette i normali token ClinDiary.

Per Regolo AI sui recap e sulla query documentale:

```bash
cp .env.example .env
```

Poi in `.env`:

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

Se il provider embeddings non supporta il parametro `dimensions`, ClinDiary ritenta automaticamente senza quel campo e salva comunque la dimensione reale ritornata in `document_chunks.embedding_dimensions`.

Per iniziare la migrazione Gemma senza rompere il comportamento esistente:

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

In questa fase:

- recap/report possono usare `gemma`
- answer generation documentale puo` usare `gemma`
- embeddings documentali possono usare `embeddinggemma`
- rerank resta sul path attuale `regolo_ai`
- i campi legacy `AI_PROVIDER` e `AI_*` restano validi come fallback di compatibilita

Per il path locale su backend host attraverso le fasi 1-3:

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

Questa modalita` attiva Gemma locale per recap/report, answer generation documentale e embeddings sul backend. Supporta in modo concreto:

- `ollama`
- server locali OpenAI-compatible (`llama_cpp`, `vllm`, `openai_compatible`)

Il mobile resta invariato e continua a parlare con il backend FastAPI. Il rerank puo` restare su `regolo_ai` oppure sul fallback `rule_based`.

Bootstrap operativo consigliato per Ollama locale user-space:

```bash
cd /path/to/ClinDiary
bash scripts/setup_local_gemma_ollama.sh --keep-server
bash scripts/smoke_local_gemma_ollama.sh
```

Il setup usa:

- `gemma4:e2b` per summary/report e document answer
- `embeddinggemma` per il retrieval embeddings
- `LOCAL_LLM_BASE_URL=http://127.0.0.1:11435`
- `AI_TIMEOUT_SECONDS=300` nel profilo locale per payload piu` lenti su CPU

Su host con RAM libera insufficiente per `gemma4:e2b`, puoi usare un fallback solo per smoke/dev:

```bash
LOCAL_GEMMA_MODEL=gemma3n:e2b bash scripts/setup_local_gemma_ollama.sh --keep-server
LOCAL_LLM_MODEL_NAME=gemma3n:e2b bash scripts/smoke_local_gemma_ollama.sh
```

Il target di migrazione rimane `Gemma 4`; `gemma3n:e2b` serve solo come profilo operativo per macchine piu` strette.

Template env dedicato:

- `apps/backend/.env.gemma-local.example`

Per il modulo `devices`:

- `Withings`, `iHealth` e `Dexcom` richiedono le rispettive credenziali client/redirect per il flusso live
- `OMRON` resta un connettore partner/SDK-BLE: il backend conserva il setup del profilo, ma la sync live richiede onboarding vendor
- `A&D Medical` puo` gia` essere bootstrap-ato con API key e ingest manuale

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
clindiary-ai-smoke --profile gemma_summary
clindiary-ai-smoke --require-external-provider
clindiary-ai-smoke --payload /percorso/payload.json --require-external-provider
clindiary-document-rag-smoke
clindiary-document-rag-smoke --profile embeddinggemma
clindiary-document-rag-smoke --profile embeddinggemma --require-external-provider
clindiary-ai-eval
clindiary-ai-eval --inputs /percorso/casi-curati
clindiary-ai-eval --inputs /percorso/casi-curati --require-external-provider
```

Il comando AI usa un payload di prova interno se non ne passi uno. Con `--require-external-provider` fallisce se il provider configurato manca o se il backend ricade sul fallback `rule_based`.
`clindiary-ai-eval` fa la stessa verifica su piu casi curati e controlla anche che il riepilogo rispetti la struttura clinica attesa.
`clindiary-document-rag-smoke` verifica invece il provider embeddings attivo e mostra un piccolo ranking locale sui passaggi di prova.

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
clindiary-notification-smoke --payload /percorso/notification.json --require-external-provider

clindiary-notification-audit
clindiary-notification-audit --require-external-provider

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

Con `--require-external-provider` il comando fallisce se il provider ricade su `log_only` oppure se nessun canale reale viene testato.

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
