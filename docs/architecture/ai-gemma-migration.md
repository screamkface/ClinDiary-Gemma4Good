# ClinDiary - Migrazione Gemma e Local-First

Data: 3 aprile 2026

## Obiettivo

Avviare una migrazione prudente del layer AI verso una stack Gemma-first senza modificare:

- logica clinica deterministica
- comportamento prodotto esistente
- fallback di sicurezza `rule_based`

## Perche` backend-host locale prima del mobile

Per ClinDiary il phase 1 corretto non e` l'inferenza on-device su Flutter.

Il backend-host locale viene prima perche`:

- migliora subito la privacy story del progetto
- mantiene stabile il prodotto esistente
- evita un rewrite Android/iOS prematuro
- si allinea bene alla narrativa hackathon: Gemma come memoria sanitaria privata e non come chatbot generico

L'inferenza mobile on-device resta rinviata a una fase successiva, dopo che il path locale lato backend sara` validato su prompt, latenza e stabilita`.

## Stato prima della migrazione

### Summary / report

- builder: `apps/backend/app/ai/summary_provider.py`
- orchestrazione: `apps/backend/app/services/insight_service.py`
- report PDF: `apps/backend/app/services/report_service.py`
- provider di default: `regolo_ai`
- modello principale: `minimax-m2.5`

### Document RAG

- provider unico: `apps/backend/app/ai/document_rag_provider.py`
- answer generation: `qwen3-8b`
- embeddings: `qwen3-embedding-8b`
- rerank: `qwen3-reranker-4b`

Prima di questa fase il selettore `AI_PROVIDER` guidava sia:

- recap/report
- document answer generation
- document embeddings
- rerank

Questo coupling rendeva rischioso introdurre Gemma in modo incrementale.

## Cosa cambia in fase 1

### 1. Summary/report Gemma in locale sul backend host

Il primo traguardo locale e` ora reale:

- daily recap
- weekly recap
- monthly recap
- pre-visit report

La modalita` supportata e`:

- `SUMMARY_AI_PROVIDER=gemma`
- `SUMMARY_AI_RUNTIME_MODE=local`

con backend locali supportati in modo concreto:

- `ollama`
- server locali OpenAI-compatible (`llama_cpp`, `vllm`, `openai_compatible`)

Il path mantiene invariati:

- prompt clinico prudente
- struttura del payload
- disclaimer
- fallback `rule_based`
- backend FastAPI come punto di orchestrazione

Configurazione nuova:

- `LOCAL_LLM_BACKEND`
- `LOCAL_LLM_BASE_URL`
- `LOCAL_LLM_MODEL_NAME`
- `LOCAL_MAX_CONTEXT_TOKENS`
- `SUMMARY_AI_PROVIDER`
- `SUMMARY_AI_MODEL_NAME`
- `SUMMARY_AI_BASE_URL`
- `SUMMARY_AI_API_KEY`
- `SUMMARY_AI_RUNTIME_MODE`
- `GEMMA_API_KEY`
- `GEMMA_BASE_URL`

Questa e` la scelta corretta per il progetto:

- privacy story forte
- impatto minimo sull'architettura
- nessun rewrite del mobile
- demo hackathon credibile con Gemma

### 2. Embedding provider separato

Le embeddings documentali vengono separate dall'answer generation.

Nuova idea architetturale:

- `DocumentRagProvider` resta responsabile di answer + rerank
- `DocumentEmbeddingProvider` diventa responsabile solo di embeddings

Questo consente di usare:

- `regolo_ai` per answer generation documentale
- `gemma` per embeddings

senza cambiare il resto della pipeline pgvector.

Configurazione nuova:

- `DOCUMENT_EMBEDDING_PROVIDER`
- `DOCUMENT_EMBEDDING_BASE_URL`
- `DOCUMENT_EMBEDDING_API_KEY`
- `DOCUMENT_EMBEDDING_RUNTIME_MODE`

In fase 1 l'uso locale delle embeddings viene preparato ma non ancora attivato.

### 3. Chiarezza dei selettori

Sono introdotti selettori capability-specific:

- `SUMMARY_AI_PROVIDER`
- `DOCUMENT_ANSWER_PROVIDER`
- `DOCUMENT_EMBEDDING_PROVIDER`
- `DOCUMENT_RERANKER_PROVIDER`

I campi legacy restano validi per compatibilita:

- `AI_PROVIDER`
- `AI_MODEL_NAME`
- `AI_BASE_URL`
- `AI_API_KEY`

## Cosa cambia in fase 2

### 1. Answer generation documentale Gemma

Viene introdotto un provider `gemma` reale anche per:

- document Q&A
- user Q&A grounded sui passaggi documentali recuperati

Il prompt prudente, i vincoli anti-diagnosi e il formato con citazioni restano invariati.

La modalita` supportata e` ora doppia:

- `DOCUMENT_ANSWER_PROVIDER=gemma`
- `DOCUMENT_ANSWER_RUNTIME_MODE=remote|local`

Quando `DOCUMENT_ANSWER_RUNTIME_MODE=local`, ClinDiary usa un runtime backend-host locale con gli stessi backend gia` supportati per i summary:

- `ollama`
- `llama_cpp`
- `vllm`
- `openai_compatible`

### 2. Split completo answer / embedding / rerank

Il modulo documentale non usa piu` un singolo provider implicito per tutto.

Ora esistono builder distinti per:

- `build_document_answer_provider`
- `build_document_embedding_provider`
- `build_document_rerank_provider`

e un composite legacy resta disponibile solo per compatibilita`.

Questo consente configurazioni reali tipo:

- `DOCUMENT_ANSWER_PROVIDER=gemma`
- `DOCUMENT_EMBEDDING_PROVIDER=gemma`
- `DOCUMENT_RERANKER_PROVIDER=regolo_ai`

senza alterare la pipeline pgvector o il retrieval SQL esistente.

### 3. Capability matrix

E` introdotta una matrice capability-specific in:

- `apps/backend/app/ai/provider_capabilities.py`

Serve a dichiarare esplicitamente:

- quali provider supportano `remote`
- quali runtime `local` sono gia` attivi
- quali combinazioni restano volutamente non supportate

### 4. Smoke operativi

Sono ora disponibili verifiche pratiche separate:

- `clindiary-ai-smoke --profile gemma_summary`
- `clindiary-document-rag-smoke --profile embeddinggemma`
- `clindiary-document-rag-smoke --mode answer --profile default`

Questo rende verificabili separatamente:

- Gemma per recap/report
- Gemma per answer generation documentale
- EmbeddingGemma per retrieval

### 5. Local-first esteso al RAG documentale

La direzione `local-first` non e` piu` limitata ai recap/report.

Ora copre:

- inferenza locale sul backend host per recap/report
- answer generation documentale locale su chunk gia` recuperati

Esiste una scaffolding dedicata per adapter locali:

- `apps/backend/app/ai/local_runtime_adapter.py`

Restano invece volutamente rinviati:

- inferenza mobile on-device

## Cosa cambia in fase 3

### 1. EmbeddingGemma locale su backend host

Le embeddings documentali possono ora usare anche un runtime locale:

- `DOCUMENT_EMBEDDING_PROVIDER=gemma`
- `DOCUMENT_EMBEDDING_RUNTIME_MODE=local`
- `LOCAL_EMBEDDING_MODEL_NAME=<your-local-embeddinggemma-model-tag>`
- `LOCAL_EMBEDDING_DIMENSIONS=1024`

Sono supportati:

- `ollama` tramite `/api/embed`
- server OpenAI-compatible tramite `/embeddings`

La pipeline pgvector resta invariata:

- chunking
- persistenza embeddings
- retrieval SQL/pgvector
- rerank separato

Target operativo consigliato nel repo:

- backend locale user-space con Ollama aggiornato
- `gemma4:e2b` come modello generativo
- `embeddinggemma` come modello embeddings
- porta dedicata `11435`
- timeout locale piu` alto (`AI_TIMEOUT_SECONDS=300`) per inference CPU-bound
- script di bootstrap: `scripts/setup_local_gemma_ollama.sh`
- script smoke: `scripts/smoke_local_gemma_ollama.sh`

Nota operativa: su host CPU con circa `7 GiB` di RAM libera, `gemma4:e2b` puo` non caricarsi. In quel caso il wiring resta valido, ma per smoke/dev conviene usare temporaneamente `gemma3n:e2b` come modello locale override, lasciando invariato il target architetturale `Gemma 4`.

### 2. Cosa resta ancora rinviato

- reranker locale
- sidecar safety tipo ShieldGemma
- inferenza mobile on-device
- routing automatico per classi diverse di device locali

## Cosa resta invariato

- `red flags`
- `screening eligibility`
- `prevention engine`
- `care-path reminders`
- `medication reminder logic`
- reranker documentale
- mobile UI e payload clinici

In particolare:

- nessuna logica deterministica viene spostata in LLM
- Gemma non decide regole cliniche

## Cosa e` volutamente rinviato

Queste fasi non implementano ancora:

- reranker Gemma o sidecar safety
- inferenza on-device reale
- runtime mobile on-device

## Direzione futura

La direzione architetturale resta:

- Gemma 4 per sintesi e recap
- EmbeddingGemma per retrieval embeddings
- eventuale ShieldGemma come sidecar safety
- modalita` local-first nel medio termine

Le fasi 1-3 preparano il percorso Gemma-first senza forzare una sostituzione totale immediata del backend AI esistente.
