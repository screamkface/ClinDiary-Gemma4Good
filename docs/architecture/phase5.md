# ClinDiary Architecture — Fase 5

## Obiettivo

Portare ClinDiary da baseline funzionale a baseline piu robusta su sicurezza, osservabilita, AI/OCR e resilienza client.

## Cosa e stato implementato

### Hardening backend

- middleware HTTP centralizzato in `apps/backend/app/core/http_middleware.py`
- `X-Request-ID` e `X-Response-Time-Ms` su tutte le risposte
- logging strutturato request/response
- rate limiting auth Redis-backed con fallback in-memory

### AI prudente provider-agnostic

- adapter `rule_based`
- adapter `openai_compatible`
- adapter `gemini_ai_studio` per Google AI Studio / Gemini API
- fallback automatico al provider deterministico se il provider esterno fallisce o non e configurato
- configurazione runtime in `app/core/config.py`

### OCR e document processing

- pipeline `pypdf` per PDF digitali
- adapter OCR `paddleocr` per immagini/scansioni
- runtime Docker predisposto con dipendenze di sistema e flag build `INSTALL_OCR`
- build verificato su immagini `backend` e `worker` con inizializzazione `PaddleOCR runtime ready`
- fallback esplicito a `ocr_pending`

### Scheduling farmaci e prevention

- `medication_schedules` esteso con:
  - `days_of_week`
  - `start_date`
  - `end_date`
  - `cycle_days_on`
  - `cycle_days_off`
  - `paused_until`
- reminder giornalieri filtrati in base alla schedule effettivamente attiva
- seed screening con availabilities regionali Italia + filtro `region_code`

### Notifiche e resilienza client

- preferenze notifiche estese con `push_enabled`, `email_enabled`, `email_address`
- registrazione device token via API
- delivery service adapter-ready:
  - `log_only`
  - `webhook` per push
  - `smtp` per email
- mobile Drift esteso con queue offline minima e request traces locali

## Confini architetturali rispettati

- business logic, delivery esterni, AI e regole cliniche restano separati
- il provider AI non sostituisce il motore deterministico red flags
- l’OCR non introduce interpretazioni cliniche
- la queue offline mobile resta nel layer infrastructural/client e non sporca la UI logic

## Gap ancora aperti

- audit trail sicurezza persistente
- metriche/tracing centralizzato
- build OCR container validato con `INSTALL_OCR=true` su ambiente target
- provider push reali (FCM/APNs)
- UI mobile avanzata per configurazione schedule farmaci
